SQS CI
======
Install like any other gem - gem install...  But it is only on github, so you need to put it in a Gemfile or clone the project.

2 executables - `run_ci` and `sqs_ci`.

The executables have a -h option to get help.

run_ci
------
This will run tests and update the github status for a commit.

sqs_ci
------
If you can get your permissions to work on aws sqs, you are a better man than I am.  Then you need to set up your github repo to send notifications to that queue, through an SNS topic.  Then it will listen for messages and run the tests on the commits.
