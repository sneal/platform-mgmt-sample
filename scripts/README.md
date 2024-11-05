# Scripts
All custome scripts go here

## Promotion Process
Run the `stage-promotion.sh` script from the `scripts/` directory using the
name of the template you want to promote, for example:
`./stage-promotion.sh sandbox aws p-redis`

The script will check that your repo state is up-to-date and clean. If there
is a workflow associated with your tile it will also be promoted. The script
will verify that the template interpolates correctly given the variables that
are present in the target environment.

You should then review the changes before checking in and pushing to trigger a
deployment. There is replacement of the environment name in the workflow so its
recommended to check this in particular. 

 In case you want to change the behaviour, you can set
 `FORCE_PROMOTE_PRODUCTS=true` which will allow the script to run with changes
 already present in your git working directory. This is useful in case you want
 to promote the director and PAS at the same time.
