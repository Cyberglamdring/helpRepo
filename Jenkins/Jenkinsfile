node('Host-Node') {
	stage("1: Git") {
		git branch: 'hkanonik', url: 'https://github.com/MNT-Lab/p192e-module.git'
        }
	
	stage('2: Build') {
		withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1'){
		    sh 'mvn clean package -f helloworld-ws/pom.xml'
	    }
	}
        
	stage('3: SonarQube') {
                def scannerHome = tool 'SonarQubeScanner';
                withSonarQubeEnv() {
			sh "${scannerHome}/bin/sonar-scanner " +
          		'-Dsonar.projectKey=hkanonik ' +
			'-Dsonar.projectName=hkanonik ' +
          		'-Dsonar.sources=helloworld-ws/src/main/java ' +
          		'-Dsonar.java.binaries=**/target/classes ' +
          		'-Dsonar.language=java '
            			
			//sh '''
                        //${scannerHome}/bin/sonar-scanner \
                        //-Dsonar.projectKey= \
                        //-Dsonar.projectName=hkanonik \
                        //-Dsonar.sources=helloworld-ws/src/main/java \
                        //-Dsonar.java.binaries=**/target/classes \
                        //-Dsonar.language=java
                        //'''
			
                }
        } 
	
	stage('4: Testing') {
		parallel(
			'Pre Integration': {
				withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1'){
                    			sh '''
                    			cd ./helloworld-ws 
                    			mvn pre-integration-test
                    			'''
                		}
            		},
            		'Integration': {
                		withMaven(jdk: 'JDK9', maven: 'Maven 3.6.1'){
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
	
	stage('5: Triggering and fetching'){
		build job: 'MNTLAB-hkanonik-child1-build-job', wait: true
		copyArtifacts filter: 'output.txt', flatten: true, projectName: 'MNTLAB-hkanonik-child1-build-job', selector: workspace()
        }
	
	stage('6: Push the Artifact to Nexus') {
                sh 'tar -zcvf pipeline-hkanonik-${BUILD_NUMBER}.tar.gz output.txt Jenkinsfile ./helloworld-ws/target/helloworld-ws.war'
                nexusArtifactUploader artifacts: [[artifactId: 'hkanonik', classifier: '', file: 'pipeline-hkanonik-${BUILD_NUMBER}.tar.gz', type: 'tar.gz']], credentialsId: 'nexus', groupId: 'pipeline', nexusUrl: 'nexus-ci.playpit.by', nexusVersion: 'nexus3', protocol: 'http', repository: 'MNT-pipeline-training/', version: '0.1'
		
             	docker.withRegistry('http://localhost:6566', 'nexus') {
                        def dockerfile = 'Dockerfile.webapp'
                        def webappImage = docker.build("localhost:6566/helloworld-hkanonik:${BUILD_NUMBER}", "-f ./dockerfiles/${dockerfile} .")
                        webappImage.push()
                }  
        }
	
	stage('7: Asking for manual approval') {
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
}
