#!/usr/bin/env bash

echo >&2 "This script is a non-working sample, at a minimum you will need to implement create-env.sh and test this script works properly"
exit 2

set -euo pipefail

# inputs from command line
readonly FROM_ENV="${1?needs environment, eg. sandbox, nonprod, prod}"
readonly IAAS="${2?needs IAAS, eg. vsphere, aws}"

# optional variables
readonly FORCE_PROMOTE_PRODUCTS=${FORCE_PROMOTE_PRODUCTS:-""}
PASSPHRASE=${PASSPHRASE:-""}
PRODUCT_NAME="${3:-""}"

# inferred working directory
WORKSPACE="$(git rev-parse --show-toplevel)"


# next we check that template interpolates correctly with the vars available in the new environment
# i.e. have all the necessary variables been defined for the target env?
validateTargetEnvironmentProductconfig() {
  local TO_REGION="${1}"
  local PRODUCT_NAME="${2}"

  # load vars file, we will use to check interpolate works
  vars_args=("")
  if [ -f "$WORKSPACE/environments/$IAAS/$TO_REGION/$TO_ENV/vars/${PRODUCT_NAME}.yml" ] ; then
    vars_args+=("--vars-file $WORKSPACE/environments/$IAAS/$TO_REGION/$TO_ENV/vars/${PRODUCT_NAME}.yml")
  fi

  # also need tf outputs to check interpolation works
  vars_args+=("--vars-file $TF_OUTPUT")

  # actual checking of interpolation
  # ${vars_args[@] needs to be globbed to pass through properly
  # shellcheck disable=SC2068
  if ! om interpolate -c "$WORKSPACE/environments/$IAAS/$TO_REGION/$TO_ENV/config/${PRODUCT_NAME}.yml" ${vars_args[@]} > /dev/null ; then
    echo >&2 "Interpolation of promoted template failed! Check the errors above, fix the $IAAS/$TO_REGION/$TO_ENV variables and try again"
    exit 2
  fi
}

promoteProductTemplateAndpipelines() {
  local TO_REGION="${1}"
  local PRODUCT_NAME="${2}"

  # promote product template file
  cp \
    "$WORKSPACE/environments/$IAAS/$FROM_REGION/$FROM_ENV/config/${PRODUCT_NAME}.yml" \
    "$WORKSPACE/environments/$IAAS/$TO_REGION/$TO_ENV/config/${PRODUCT_NAME}.yml"
  
  # if it exists, promote the individual product Concourse pipeline
  if [ -f "$WORKSPACE/ci/pipelines/$IAAS-$FROM_ENV-$PRODUCT_NAME.yml" ] ; then
    sed \
      -e "s/${FROM_ENV}/${TO_ENV}/g" \
      -e "s/${FROM_REGION}/${TO_REGION}/g" \
      "$WORKSPACE/ci/pipelines/$IAAS-$FROM_ENV-$PRODUCT_NAME.yml" > \
      "$WORKSPACE/ci/pipelines/$IAAS-$TO_ENV-$PRODUCT_NAME.yml"
  fi

  # promote the end-to-end Concourse pipeline
  sed \
    -e "s/${FROM_ENV}/${TO_ENV}/g" \
    -e "s/${FROM_REGION}/${TO_REGION}/g" \
    "$WORKSPACE/ci/pipelines/$IAAS-$FROM_REGION-$FROM_ENV.yml" > \
    "$WORKSPACE/ci/pipelines/$IAAS-$TO_REGION-$TO_ENV.yml"
}

initTargetEnvironmentTerraform() {
  local TO_REGION="${1}"

  export REGION="$TO_REGION"
  export ENV_NAME="$TO_ENV"

  # shellcheck source=/dev/null
  source "${WORKSPACE}/scripts/create-env.sh"`

  unset REGION
  unset ENV_NAME
}

createListOfProductsToPromote() {
  PRODUCTS=()
  if [ -z "$PRODUCT_NAME" ]; then
    local sourceconfig="${WORKSPACE}/environments/${IAAS}/${FROM_REGION}/${FROM_ENV}/config"
    while IFS= read -r -d $'\0'; do
      f=$(basename "${REPLY%.yml}")
      PRODUCTS+=("$f")
    done < <(find "${sourceconfig}" -type f -name '*.yml' -print0)
  else
   PRODUCTS=("$PRODUCT_NAME")
  fi
}

promoteToRegion() {
  local TO_REGION="${1}"

  initTargetEnvironmentTerraform "$TO_REGION"

  echo "Promoting $IAAS $FROM_REGION $FROM_ENV -> $TO_REGION $TO_ENV"

  for product in "${PRODUCTS[@]}"; do
    echo "  $product"
    promoteProductTemplateAndpipelines "$TO_REGION" "$product"
    validateTargetEnvironmentProductconfig "$TO_REGION" "$product"
  done

  echo "Successfully completed $IAAS $FROM_REGION $FROM_ENV -> $TO_REGION $TO_ENV"
}

validateGitWorkingCopyIsUpToDate() {
  # check we are on master, have pulled everything and don't have changes in the working directory
  git pull --ff-only
  if output=$(git status --porcelain) && [ -z "$output" ] || [ -n "$FORCE_PROMOTE_PRODUCTS" ]; then
    # working directory clean
    echo >&2 "Git repo is up-to-date, proceeding with promotion from $FROM_ENV to $TO_ENV"
  else
    # uncommitted changes
    echo >&2 "Current repo status not the same as the latest checked in to remote/you have uncommitted changes."
    echo >&2 "You can override this check by setting FORCE_PROMOTE_PRODUCTS=true. Exiting..."
    exit 1
  fi
}

main() {
  if [[ "$FROM_ENV" == "sandbox" ]]; then
    TO_ENV="nonprod"
  elif [[ "$FROM_ENV" == "nonprod" ]]; then
    TO_ENV="prod"
  else
    echo >&2 "The specified environment \"$FROM_ENV\" does not exist or is not supported as a source"
    exit 1
  fi

  # TODO: this should be data driven
  if [[ "$IAAS" == "vsphere" ]]; then
    FROM_REGION="northeurope"
    if [[ "$TO_ENV" == "nonprod" ]]; then
      REGIONS=(northeurope)
    elif [[ "$TO_ENV" == "prod" ]]; then
      REGIONS=(northeurope uksouth ukwest)
    else
      echo >&2 "Could not find target region(s) for \"$TO_ENV\""
      exit 1
    fi
  elif [[ "$IAAS" == "aws" ]]; then
    FROM_REGION="eu-west-2"
    REGIONS=(eu-west-2)
  else
    echo >&2 "The specified IaaS \"$IAAS\" does not exist or is not supported as a source"
    exit 1
  fi

  if [ -z "$FORCE_PROMOTE_PRODUCTS" ]; then
    validateGitWorkingCopyIsUpToDate
  fi

  createListOfProductsToPromote

  for region in "${REGIONS[@]}"; do
    promoteToRegion "$region"
  done
}

main "$@"
