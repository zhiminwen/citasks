# CI Tools for Gitlab + Jenkins

This gem bootstraps the initial setup for gitlab and jenkins integration.

## Install and require 
Install 
```
gem install citools
```
Use
```
require 'citools'
```

## Usage
There is a rake task library that you can require to start

In your rake task file
```
require 'citasks'
require 'dotenv'
Dotenv.load
```

In the .env file define the following
```
REPO_NAME=
GITLAB_USER=
GITLAB_PASS=

GITLAB_BASE_URL=
GITLAB_IN_CLUSTER_BASE_URL=
GITLAB_API_TOKEN=


JOB_NAME=
JENKINS_URL=
JENKINS_IN_CLUSTER_URL=
JENKINS_GIT_USER_CREDENTIAL_ID=

JENKINS_USER= 
JENKINS_USER_API_TOKEN=
```

Then run 
```
rake -T
```

The tasks is shown as below,

```
rake Gitlab:01_create_new_repo      # create a new gitlab repo
rake Gitlab:02_webhook              # setup webhook
rake Gitlab:03_delete               # delete
rake Jenkins:01_create_new_project  # create a new project
rake Jenkins:02_delete              # delete
```