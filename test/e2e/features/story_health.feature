@story_health
Feature: End-to-end health check

    User goes through a "day in the life of" CRC. They set up
    and start CRC. They then create a project and deploy an app.
    They check on the app and delete the project. They stop CRC
    and delete the CRC VM.

    @linux @darwin @startstop
    Scenario: Start CRC
        Given executing crc setup command succeeds
        When setting config property "memory" to value "12000" succeeds
        When starting CRC with default bundle succeeds
        Then stdout should contain "Started the OpenShift cluster"

    @linux @darwin
    Scenario: Login to cluster
        Given checking that CRC is running
        Then executing "eval $(crc oc-env)" succeeds
        And login to the oc cluster succeeds

    @windows @startstop
    Scenario: Start CRC on Windows
        Given executing crc setup command succeeds
        When setting config property "memory" to value "12000" succeeds
        When starting CRC with default bundle and nameserver "10.75.5.25" succeeds
        Then stdout should contain "Started the OpenShift cluster"

    @windows
    Scenario: Login to cluster
        Given executing "crc oc-env | Invoke-Expression" succeeds
        When checking that CRC is running
        Then login to the oc cluster succeeds

    @darwin @linux @windows
    Scenario: Create project
        When executing "oc new-project testproj" succeeds
        Then stdout should contain
            """
            Now using project "testproj" on server "https://api.crc.testing:6443".
            """
        And stdout should contain "You can add applications to this project with the 'new-app' command."

    @darwin @linux @windows @testdata
    Scenario: Create and test app
        When executing "oc create deployment httpd-example --image=registry.access.redhat.com/ubi8/httpd-24 --port=8080" succeeds
        Then stdout should contain "deployment.apps/httpd-example created"
        When executing "oc rollout status deployment httpd-example" succeeds
        Then stdout should contain "successfully rolled out"
        When executing "oc create configmap www-content --from-file=index.html=httpd-example-index.html" succeeds
        Then stdout should contain "configmap/www-content created"
        When executing "oc set volume deployment/httpd-example --add --type configmap --configmap-name www-content --name www --mount-path /var/www/html" succeeds
        Then stdout should contain "deployment.apps/httpd-example volume updated"
        When executing "oc expose deployment httpd-example --port 8080" succeeds
        Then stdout should contain "httpd-example exposed"
        When executing "oc expose svc httpd-example" succeeds
        Then stdout should contain "httpd-example exposed"
        When with up to "20" retries with wait period of "5s" http response from "http://httpd-example-testproj.apps-crc.testing" has status code "200"
        Then executing "curl -s http://httpd-example-testproj.apps-crc.testing" succeeds
        And stdout should contain "Hello CRC!"

    @darwin @linux @windows @startstop
    Scenario: Stop and start CRC, then check app still runs
        When executing "crc stop" succeeds
        Then checking that CRC is stopped
        When starting CRC with default bundle succeeds
        Then checking that CRC is running
        And with up to "4" retries with wait period of "1m" http response from "http://httpd-example-testproj.apps-crc.testing" has status code "200"
        Then executing "curl -s http://httpd-example-testproj.apps-crc.testing" succeeds
        And stdout should contain "Hello CRC!"

    @darwin @linux @windows
    Scenario: Clean up project
        When executing "oc delete project testproj" succeeds

    @darwin @linux @windows @startstop
    Scenario: Switch off CRC
        When executing "crc delete -f" succeeds
        And execute crc cleanup command succeeds
