# Canvas SIS scripts

This folder contains two Ruby scripts for Canvas SIS integration:
* sis_upload.rb: 
    * uploads the SIS zip file into Canvas using [Canvas SIS_imports API](https://canvas.instructure.com/doc/api/sis_imports.html)
    * created practice course for new instructors;
* sis_set_url.rb: 
    * get Canvas URL values for all current term sections from SIS system
    * get all sections in published Canvas courses for current term, using [Canvas Courses API](https://canvas.instructure.com/doc/api/courses.html)
    * compare values from those two lists
    * update/delete the section's Canvas course URL value if necessary 

# Local Development

You can run the scripts locally without installing the dependencies manually by leveraging the `Dockerfile`, `docker-compose.yml`, and Docker Desktop. To run with Docker, do the following:

1. Prepare the env file:
    ```
    cp .env_example .env
    ```
2. Update the `.env` with configuration values
3. Set the PROCESS setting in `Dockerfile` to the proper Ruby script
4. Build image: 
    ```
    docker compose build
    ```
5. Run the container with the image
    ```
    docker compose up
    ```

