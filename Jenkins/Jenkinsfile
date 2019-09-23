@Library('hkanonik_lib') _
	
node('Host-Node') {
//        try {
		// This stage in 'Pipeline script from SCM'
		/*
		stage ("1: Git") {
                        git branch: 'hkanonik', url: 'https://github.com/MNT-Lab/p192e-module.git'
                }
        	*/
                stage ('2: Build') {
                        withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1') {
                        sh 'mvn clean package -f helloworld-ws/pom.xml'
                	}
                }
        
                stage ('3: SonarQube') {
                        def scannerHome = tool 'SonarQubeScanner';
                        withSonarQubeEnv() {
				sh """
                                ${scannerHome}/bin/sonar-scanner \
                                -Dsonar.projectKey=hkanonik \
                                -Dsonar.projectName=hkanonik \
                                -Dsonar.sources=helloworld-ws/src/main/java \
                                -Dsonar.java.binaries=**/target/classes \
                                -Dsonar.language=java
                                """				
                        }
                } 
        
                stage ('4: Testing') {
                        parallel(
                                'Pre Integration': {
                                        withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1') {
                                                sh '''
                                                cd ./helloworld-ws 
                                                mvn pre-integration-test
                                                '''
                                        }
                                },
                                'Integration': {
                                        withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1') {
                                                sh '''
                                                cd ./helloworld-ws
                                                mvn integration-test
                                                '''
                                        }
                                },
                                'Post Integration': {
                                        withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1'){
                                                sh '''
                                                cd ./helloworld-ws
                                                mvn post-integration-test
                                                '''
                                        }
                                }
                        )
                }
                
                stage ('5: Triggering and fetching') {
                        build job: 'MNTLAB-hkanonik-child1-build-job', wait: true
                        copyArtifacts filter: 'output.txt', flatten: true, projectName: 'MNTLAB-hkanonik-child1-build-job', selector: workspace()
                }
                
                stage ('6: Push the Artifact to Nexus') {
                        sh 'tar -zcvf pipeline-hkanonik-${BUILD_NUMBER}.tar.gz output.txt Jenkinsfile ./helloworld-ws/target/helloworld-ws.war'
                        pushStage('MNT-pipeline-training')
			//nexusArtifactUploader artifacts: [[artifactId: 'hkanonik', classifier: '', file: 'pipeline-hkanonik-${BUILD_NUMBER}.tar.gz', 
                        //                                 type: 'tar.gz']], credentialsId: 'nexus', groupId: 'pipeline', nexusUrl: 'nexus-ci.playpit.by', 
                        //                                 nexusVersion: 'nexus3', protocol: 'http', repository: 'MNT-pipeline-training/', version: '0.1'
                        
                        docker.withRegistry('https://registry-ci.playpit.by', 'nexus') {
                                pushStage('docker')
				//def dockerfile = 'Dockerfile.webapp'
				//def webappImage = docker.build("registry-ci.playpit.by/helloworld-hkanonik:${BUILD_NUMBER}", "-f ./dockerfiles/${dockerfile} .")
                                //webappImage.push()
                        }  
                }
                
                stage ('7: Asking for manual approval') {
                        // v2 aborted
                        timeout(time: 15, unit: 'MINUTES') {
                             input id: 'deployment', message: 'Do you want to continue deploying the artifacts?', ok: 'Yes'
                        }
                
                        // v1 autodeploy
                        /*
                        try {
                                timeout(time:15, unit:'MINUTES') {
                                        env.approval = input message: 'Do you want to continue deploying the artifacts?', ok: 'Continue',
                                        parameters: [choice(name: 'approval', choices: 'Yes\nNo', description: 'Continue deploying the artifacts?')]
                                        
                                        if (env.approval == 'Yes'){
                                                env.DPROD = true
                                        } else {
                                                env.DPROD = false
                                        }
                                }
                        } catch (error) {
                                env.DPROD = true
                                echo 'Timeout has been reached! Deploying automatically'
                        } 
                        */
                }
		
		stage ('8: Deployment') {
                        sh """
                        $HOME/kubectl apply -f ./k8s-webapp/webapp-service.yaml
                        $HOME/kubectl apply -f ./k8s-webapp/webapp-ingress.yaml
                        cat << EOF | $HOME/kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
    name: hkwebapp-dep
    namespace: hkanonik
spec:
    replicas: 1
    template:
        metadata:
            labels:
                app: webapp
        spec:
            containers:
            - name: hk-webapp
              image: registry-ci.playpit.by/helloworld-hkanonik:${BUILD_NUMBER}
              ports:
              - name: http-webapp
                containerPort: 8080
EOF
			"""
                }
		/*
  		stage ('9: Sanity check') {
      			def response_value = 'HelloWorldService?wsdl'
       			try {
            			sh "curl http://hkanonik-app.k8s.playpit.by/ | grep ${response_value}"
            			return true
      			} catch (resp) {
        			echo "${response_value} NOT FOUND!"
        			currentBuild.result = 'FAILURE'
        			
			}
    		} 
		*/
		/*                
		// send e-mail
                currentBuild.result = 'SUCCESS'
                mail bcc: '', 
                body: "<b>BUILD SUCCESS</b><br><br>Project: ${env.JOB_NAME} <br>Build Number: ${env.BUILD_NUMBER} <br> URL build: <a href=${env.BUILD_URL}> ${env.JOB_NAME}</a>", 
                cc: '', 
                // from: 'esscyh@gmail.com', 
                replyTo: '', 
                subject: 'Jenkins notify - Success', 
                to: 'hleb_kanonik@epam.com',
                mimeType: 'text/html'
		
        } catch (any) {
                currentBuild.result = 'FAILURE'
                mail bcc: '', 
                body: "<b>BUILD FAILURE</b><br><br>Project: ${env.JOB_NAME} <br>Build Number: ${env.BUILD_NUMBER} <br> URL build: <a href=${env.BUILD_URL}> ${env.JOB_NAME}</a><br><br><b>FAILURE CODE:</b><br><i>${any}</i>", 
                cc: '', 
                // from: 'esscyh@gmail.com', 
                replyTo: '', 
                subject: 'Jenkins notify - Failure', 
                to: 'hleb_kanonik@epam.com',
                mimeType: 'text/html'
        }
	*/	
}
