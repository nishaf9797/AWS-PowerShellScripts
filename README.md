# AWS-PowerShellScripts
Scripts for AWS

# CustomInventorySetupWindows.ps1
This script will create a JSON File of Licensing and BillingInfo inside the EC2 Instance. The Script will run and get the desired information from the Instance and create the JSON File in the Custom Inventory Path of AWS.
Now you can run this script at a certain frequency using Run Command in System Manager or you can embed this script in each EC2 Instance, and when you run the CustomInventory Setup Script it will pull all the required values from the Json and show them in the Inventory Tab for each Instance.

# TagVolumeWithMountPoint.ps1
This Script add Drive Name tag to the Volumes attached to an Instance.
For Windows it will get all the Drive Names like C, D, E etc. and add this Drive Letter to the Volume associated to it. Same is the case for the linux, it will get the directory name on which the volume is mounted and tag that volume with that directory name.  
