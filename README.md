# Microservices Deployment

## Prerequisites

For local testing, you should install Docker and Docker Compose. 

* Instructions to install Docker can be found here: https://docs.docker.com/install/
* Instructions to install Compose can be found here: https://docs.docker.com/compose/install/

## Usage
To deploy the initial environment, run the following command:

```bash
docker-compose up --build
```

This command will build the containers and bring up the environment. Note that you can add the ```-d``` flag to the end of the command to run detached.

This command can also be used to deploy new versions of the application code, as it will rebuild anything in the app subdirectories


## Explanation of choices
1. Modified the Flask application to use MySQL instead of sqlite
    * ```autoincrement``` isn't valid syntax in MySQL, switched to ```auto_increment```
1. Modified ```database.sql``` to add command for creating sample db and selecting it 
    * This file is only run once during the initial docker-compose build, but I've included ```if not exists``` on the create statement to be safe
1. ```docker-compose.yml``` file contains three containers. App containers are built from a Dockerfile, but the database has no special configuration beyond a SQL file to import and simply uses a base image instead
1. There is only one Dockerfile for both parts of the Python app. This was done to minimize the amount of code that needs to be managed
    * Dockerfile is layer cached to prevent unneccesary rebuilds
    * The downside to this approach is that the portal and hardware containers will both rebuild if the other is modified. Given how lightweight they are this is not currently much of an issue, but if the apps were larger or took longer to build it would be worth switching to one Dockerfile per app
1. Some modifications to ```hardware.py``` were required to account for using MySQL in place of sqlite
1. Changed request string in portal.py to ```requests.get('http://hardware:5001/hardware/').json()``` since container can be referenced by service name
1. For the requirement to create the virtual networks for the public and private sections of the app: there is no need to explicitly define networks as docker-compose handles this implicitly. The hardware and database service are private by default, and portal is public because port 5000 is exposed explicitly
1. For scaling manually, you can scale with ```docker-compose up --scale hardware=2```, etc. 
1. Script to deploy new builds: ```docker-compose up --build -d``` - builds app and runs a detached ```docker-compose up``` command

## Notes and Extra Credit

This is an example of a non-production deployment. In production certain things would need to be modified, such as the server running the Python app, the plain text connection information for the database, etc.

For auto-scaling, there are a number of options:
- Kubernetes has service scaling, and this project could be fairly easily transitioned to Kubernetes using ```kompose```
- Given the Docker structure in place here, Docker Swarm on AWS is a good candidate. Create the Swarm, spin up the initial services and set up CloudWatch triggers to scale Swarm
- Make use of a service like AWS Auto Scaling

As for the performance issue, Python has a couple of built-in options that can be used to account for slow or CPU-intensive processes. I've implemented one solution using simple multithreading, but could have used multiprocessing or concurrent futures, etc instead. Likewise we could leverage things like AWS Lambda in order to offload a lot of the work to a serverless function instead of spinning up anything with more overhead. 
