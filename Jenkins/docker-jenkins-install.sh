# first of all Dicker -> settings -> Shared Drivers -> select
# on drive create folder jenkins_home
sharedDrive=c:/jenkins_home
containerId=967eb2e3dc6b
docker run -d -p 8080:8080 -p 50000:50000 -v $sharedDrive:/var/jenkins_home jenkins
docker exec -it $containerId cat /var/jenkins_home/secrets/initialAdminPassword
