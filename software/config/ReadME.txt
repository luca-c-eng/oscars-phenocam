Configuration file examples.

During installation, create the following files on the RPi:
  /etc/phenocam/settings.txt         → copy from settings_example.txt, fill in values
  /etc/phenocam/server.txt           → one SFTP server hostname per line (leave empty to disable)
  /etc/phenocam/ftp_credentials.txt  → 5-line positional file with FTP credentials
                                       DO NOT commit this file to any repository

The files in this directory are EXAMPLES only — they are not used directly by the system.
