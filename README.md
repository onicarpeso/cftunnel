```markdown
# Cloudflare Tunnel Script

This bash script automates the creation and management of Cloudflare tunnels for exposing local applications to the internet. It simplifies the process of setting up a secure connection between your local server and Cloudflare's global network, allowing you to access your application via a custom domain.

## Features

*   **Automated Tunnel Creation:** Creates a new Cloudflare tunnel if one doesn't already exist with the specified name.
*   **Configuration File Generation:** Automatically generates a `cloudflared` configuration file (`cloudflared-<appname>.yml`) with the necessary settings, including the tunnel ID, credentials file path, origin certificate path, and ingress rules.
*   **DNS Record Management:** Checks for an existing DNS record for your subdomain and creates one if it doesn't exist.  This script assumes you want a DNS record of type `CNAME` that points to the cloudflare tunnel.
*   **Background Execution with Logging:** Runs the `cloudflared` tunnel process in the background and redirects standard output and standard error to a log file (`<appname>-cloudflared.log`).
*   **Process Management:** Saves the process ID (PID) of the running tunnel in a file (`<appname>-cloudflared.pid`) for easy stopping and restarting.
*   **Process Verification:**  Checks to make sure the tunnel started successfully.
*   **Error Handling:** Provides informative error messages and exits if required arguments are missing, the Cloudflare origin certificate is not found, tunnel creation fails, or tunnel startup fails.
*   **Existing Tunnel Management**:  The script provides the functionality to stop and restart running tunnels associated with the specified `appname`.

## Prerequisites

*   **Cloudflare Account:** You'll need a Cloudflare account and a domain registered with Cloudflare.
*   **Cloudflared:**  Install the `cloudflared` command-line tool.  You can download it from the [Cloudflare website](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/download-cloudflared/).
*   **Cloudflare Origin Certificate:** Authenticate with Cloudflare and download the origin certificate.  This typically resides in `~/.cloudflared/cert.pem`. You can obtain the certificate using: `cloudflared tunnel login`.

## Usage

```bash
./your_script_name.sh <appname> <domain> <local-port>
```

*   `<appname>`: The name of your application (used for the tunnel name, config file name, log file name, and subdomain).  For instance, if your app is called "my-app", you would assign this to the appname.
*   `<domain>`: Your domain (e.g., `example.com`).
*   `<local-port>`: The port number your application is listening on locally (e.g., `3000`).

**Example:**

```bash
./tunnel.sh myapp example.com 3000
```

This will:

1.  Check for the Cloudflare origin certificate.
2.  Create a tunnel named `myapp-tunnel` (if it doesn't exist) using the Cloudflare API.
3.  Generate a configuration file named `cloudflared-myapp.yml`.
4.  Create a DNS record for `myapp.example.com` (if it doesn't exist), pointing to the Cloudflare tunnel.
5.  Start the tunnel in the background.
6.  Save the PID of the tunnel process to `myapp-cloudflared.pid`.
7.  Log tunnel output to `myapp-cloudflared.log`.

## Script Breakdown

*   **Argument Parsing:**  Validates the presence of the required arguments (`appname`, `domain`, `local-port`).
*   **Certificate Check:**  Verifies the existence of the Cloudflare origin certificate file.
*   **Tunnel Existence Check:** Determines if a tunnel with the specified name already exists using `cloudflared tunnel list` and `grep`.
*   **Tunnel Creation:**  Creates a new Cloudflare tunnel using `cloudflared tunnel create`.
*   **Configuration File Generation:** Creates the `cloudflared-<appname>.yml` configuration file using a "here document" (`cat << EOF ... EOF`).
*   **DNS Record Creation** Creates the `CNAME` record to automatically route traffic.
*   **Tunnel Startup:** Starts the `cloudflared tunnel run` command in the background using `&` and redirects standard output and standard error to a log file.
*   **PID Management:** Saves the process ID to a file so the process can be managed easily.
*   **Logging:** Redirects the tunnel's output to a file for debugging and monitoring.

## Important Considerations

*   **Security:** This setup relies on Cloudflare's security features. Keep your `cloudflared` tool and Cloudflare account secure.
*   **Dependencies:** Ensure you have `cloudflared` installed and configured correctly.
*   **Firewall:**  Make sure your firewall allows traffic to your application on the specified `<local-port>`.
*   **Domain Configuration:** Your domain's nameservers must be pointed to Cloudflare for this script to work correctly. This step is outside the scope of this script.
*   **Cleanup:** If you delete the Cloudflare tunnel through the Cloudflare dashboard, you might need to manually delete the DNS record created by the script.
*   **Error Handling:** It's recommended to improve the error handling to better catch and report unexpected issues.
*   **Stopping the Tunnel**:  If you want to stop the script you can do this with `kill $(cat ${APPNAME}-cloudflared.pid)`.
