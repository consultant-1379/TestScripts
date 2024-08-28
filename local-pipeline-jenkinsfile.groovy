@Library('ci-pipeline-library') _

def call() {
    node('') {
        stage('Local Stage') {
            echo('This is a local stage for local people')
        }
        stage('Our USAT') {
            echo('This is the local USAT stage')
            userStoryAcceptanceTest()
        }
    }
}

return this;
