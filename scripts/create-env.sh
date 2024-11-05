#!/bin/bash

[ -z "$WORKSPACE" ] && echo "Missing required env var WORKSPACE" && exit 1
[ -z "$IAAS" ] && echo "Missing required env var IAAS" && exit 1
[ -z "$REGION" ] && echo "Missing required env var REGION" && exit 1
[ -z "$ENV_NAME" ] && echo "Missing required env var ENV_NAME" && exit 1


# TODO: generate OM CLI connection info
