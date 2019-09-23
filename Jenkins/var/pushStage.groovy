def call(String repository) {
        if (repository == 'MNT-pipeline-training'){
                nexusArtifactUploader artifacts: [[artifactId: 'hkanonik', classifier: '', file: 'pipeline-hkanonik-${BUILD_NUMBER}.tar.gz', 
                                        type: 'tar.gz']], credentialsId: 'nexus', groupId: 'pipeline', nexusUrl: 'nexus-ci.playpit.by', 
                                        nexusVersion: 'nexus3', protocol: 'http', repository: 'MNT-pipeline-training/', version: '0.1'
        } 

        if(repository == 'docker') {             
                docker.withRegistry('https://registry-ci.playpit.by', 'nexus') {
                        def dockerfile = 'Dockerfile.webapp'
                        def webappImage = docker.build("registry-ci.playpit.by/helloworld-hkanonik:${BUILD_NUMBER}", "-f ./dockerfiles/${dockerfile} .")
                        webappImage.push()
                } 
        } 
}