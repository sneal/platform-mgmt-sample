# Platform Management Sample Repo Layout
Sample repository layout for managing TAS foundations via Platform Management.

## Assumptions
All environment's pipeline(s) run off the master or main branch. Each foundation
has it's own unique config folder so that configs and versions are promoted via
the stage-promotion shell script. This allow us to avoid needing to work off a
branch per environment and implement an easy to follow Pull Request workflow.

## Environments

### IaaSes
We have two distinct IaaSes:
- vSphere
- AWS

#### vSphere
Within vSphere we have multiple data centers or regions:
- North Europe
- UK South
- UK West

North Europe houses our sandbox and nonprod (dev) foundations. It also has a 
production foundation.

UK South and UK West only have a single production foundation. UK South is our
cold spare foundation and UK West is our hot failover foundation.

#### AWS
Our AWS foundations currently live only in a single region and house 3
foundations: sandbox, nonprod and prod. In the future we will have multiple
production AWS foundations.
