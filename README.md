# Install Shinobi with Docker
#### 2024-05-07

1. Download this repository.
    - If you **do not have Docker** installed run `sh INSTALL/docker.sh`.
2. Run the preparation and starter script.
    ```
    bash setup_and_run.sh
    ```

**Script Failing? Run this.**

    ```
    apt install dos2unix -y && dos2unix entrypoint.sh && chmod +x entrypoint.sh && dos2unix setup_and_run.sh && chmod +x setup_and_run.sh && bash setup_and_run.sh
    ```
