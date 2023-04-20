IBM Spectrum Scale (GPFS) AFM Deployment Guide
========================================================

- **Prerequisites**
-------------

User need to have primary/source and disaster recovery(DR)/target Spectrum Scale clusters standup with the network connectivity and GUI & Admin Node on both sides.

It is assumed that you are familiar with the creating Spectrum Scale cluster procedure. In case, you want to learn more, please follow the instructions 
mentioned at https://github.com/vertexblue/gcp-spectrum-scale-tf/blob/main/docs/gcp.md .

Now you can create primary and dr clusters from the same directory, let define terraform workspaces to manage the state of resources for the both clusters.
Go to directory "gcp_scale_templates/gcp_existing_vpc_scale", there are already two sample cluster profiles 1) Production cluster - gpfs-01.tfvars 2) Disaster recovery cluster gpfs-02.tfvars.

- **Infrastructure creation**
    1. Create terraform workspace to provision resources.
    ```
    terraform workspace new prd
    ```
    2. Select terraform workspace to provision resources.
    ```
    terraform workspace select prd    
    ```
    3. Create production/primary cluster
    ```
    terraform apply --var-file=gpfs-01.tfvars
    ```

    4. Create terraform workspace to provision resources.
    ```
    terraform workspace new prd
    ```
    5. Select terraform workspace to provision resources.
    ```
    terraform workspace select prd    
    ```
    6. Create dr/secondary cluster
    ```
    terraform apply --var-file=gpfs-02.tfvars
    ```

- **DR Configuration Creation**

  Once clusters is created, based on your cluster prefix choice, the automation has created a cluster profile under the /opt/IBM subdirectory as following:
  ```shell
  /opt/IBM
  ├── <Primary Cluster Profile e.g. gpfs-01>/
  │   └── spectrum-scale-install-ansible/
  │       └── afm-dr/
  │           └──AFM DR Playbook and configuration file
  └── <DR Cluster Profile e.g. gpfs-02>/
  ```
  e.g. 
  - Production cluster - /opt/IBM/gpfs-01
  - Disaster recovery cluster - /opt/IBM/gpfs-02

  Define AFM fileset mapping in afm-dr-config.json in the following format:

  ```json
  {
    "source_scale_gui_username": "source_scale_gui_username",
    "source_scale_gui_password": "source_scale_gui_password",
    "source_scale_gui_hostname": "source_scale_gui_ip_address",
    "target_scale_gui_username": "target_scale_gui_username",
    "target_scale_gui_password": "target_scale_gui_password",
    "target_scale_gui_hostname": "target_scale_gui_ip_address",
    "afm_dr_mappings": [
        {
            "source_dir": "source_dir",
            "target_dir": "target_dir",
            "source_filesystem_mountpoint": "source_filesystem_mountpoint",
            "target_filesystem_mountpoint": "target_filesystem_mountpoint",
            "source_scale_filesystem": "source_scale_filesystem",
            "target_scale_filesystem": "target_scale_filesystem"
        }
    ]
  }  
  ```
  The following is example file.

  ```json
    {
        "source_scale_gui_username": "admin",
        "source_scale_gui_password": "Passw0rd",
        "source_scale_gui_hostname": "192.168.8.4",
        "target_scale_gui_username": "admin",
        "target_scale_gui_password": "Passw0rd",
        "target_scale_gui_hostname": "192.168.9.3",
        "afm_dr_mappings": [
            {
                "source_dir": "primary1",
                "target_dir": "dr1",
                "source_filesystem_mountpoint": "/gpfs/prdfs1",
                "target_filesystem_mountpoint": "/gpfs/drfs1",
                "source_scale_filesystem": "prdfs1",
                "target_scale_filesystem": "drfs1"
            },
            {
                "source_dir": "source",
                "target_dir": "source",
                "source_filesystem_mountpoint": "/gpfs/prdfs2",
                "target_filesystem_mountpoint": "/gpfs/drfs2",
                "source_scale_filesystem": "prdfs2",
                "target_scale_filesystem": "drfs2"
            }
        ]
    } 
    ```

- **Run playbook**

The AFM DR playbook can be executed using wrapper file.

  - Using the automation script:

    ```shell
    $ cd <>/afm-dr/
    $ ./run-afm-dr.sh
    ```   

**Note:**
  An advantage of using the automation script is that it will generate ansible inventory files (afm-dr-inventory.ini) based on the AFM configuration file in the same directory.

- **Playbook execution screen**

  Playbook execution starts here:

  ```shell
  Running #### ansible-playbook -i afm-dr-inventory.ini afm-dr-playbook.yml

  PLAY #### [all]
  **********************************************************************************************************

  TASK #### [Gathering Facts]
  **********************************************************************************************************
  ok: [set fact]
  
  TASK [target Cluster (access) | Initialize variables]               
  *********************************************************************************************************
  ok: [Get cluster information]
  ...
  ```

  Playbook recap:

  ```shell
  #### PLAY RECAP
  ***************************************************************************************************************
  192.168.8.6                : ok=80   changed=10   unreachable=0    failed=0    skipped=10   rescued=0    ignored=1
  192.168.9.4                : ok=79   changed=10   unreachable=0    failed=0    skipped=3    rescued=0    ignored=0
  ```

Troubleshooting
---------------
You can verify the AFM fileset on the source filesystem using following command.

  ```shell
  [root@gpfs-01-desc-instance-1 pr22]# mmafmctl prdfs2 getstate
  Fileset Name    Fileset Target                                Cache State          Gateway Node    Queue Length   Queue numExec
  ------------    --------------                                -------------        ------------    ------------   -------------
  primary1        gpfs:///gpfs/drfs2/secondary1                 Active               gpfs-01-storage-instance-1.us-central1-a 0   23
  pr22            gpfs:///gpfs/drfs2/dr22                       Active               gpfs-01-storage-instance-1.us-central1-a 0   1
  pr44            gpfs:///gpfs/drfs1/dr44                       Active               gpfs-01-storage-instance-1.us-central1-a 0   1
  ```

You can create file(s) on the primary/source cluster and it will be replicated on the dr/target cluster within few minutes based on file size.

**Note:**
  The source directory on the primary cluster should be always on the root location. Here the source directoy is called a junction location. The junction is created in the current directory and has the same name as the fileset being linked. After the command completes, the new junction appears as an ordinary directory, except that the user is not allowed to unlink or delete it with the rmdir command it. The user can use the mv command on the directory to move to a new location in the parent fileset, but the mv command is not allowed to move the junction to a different fileset.

- **DR Configuration Creation**

  The following are the manual script that will support setting up Primary and DR cluster for AFM DR capability.

  Go to DR cluster and run following commands.
    ```shell
    mmchconfig afmEnableADR=yes -i
    mmauth add gpfs-01.cluster -k /var/mmfs/ssl/source_rsa.pub
    mmauth grant gpfs-01.cluster -f drfs1
    mmafmconfig enable /gpfs/drfs1
    mmauth grant gpfs-01.cluster -f drfs2
    mmafmconfig enable /gpfs/drfs2
    mmchnode -N gpfs-02-storage-instance-1,gpfs-02-storage-instance-2 --gateway
    ```
  Go to Production cluster and run following commands.
    ```shell
    mmchconfig afmEnableADR=yes -i
    mmremotecluster add gpfs-02.cluster -n gpfs-02-storage-instance-1,gpfs-02-storage-instance-2 -k /var/mmfs/ssl/target_rsa.pub
    mmremotefs add drfs1 -f drfs1 -C gpfs-02.cluster -T "/gpfs/drfs1" 
    mmremotefs add drfs2 -f drfs2 -C gpfs-02.cluster -T "/gpfs/drfs2" 
    mmmount drfs1 -a
    mmmount drfs2 -a
    ```
  AFM Setup

    On production cluster
    ```shell
    mmcrfileset prdfs1 primary1 -p afmMode=primary --inode-space=new -p afmtarget=gpfs:///gpfs/drfs1/secondary1 -p afmRPO=60
    ```

    On DR cluster
    ```shell
    mmcrfileset drfs1 secondary1 -p afmMode=secondary --inode-space=new -p afmPrimaryId=13715671027130937321-0608A8C06441B0E5-1
    mmlinkfileset drfs1 secondary1 -J /gpfs/drfs1/secondary1
    ```
    On production cluster
    ```shell
    mmlinkfileset prdfs1 primary1 -J /gpfs/prdfs1/primary1
    ```
  Test – Any files written/updated on /gpfs/prdfs1/primary1 directory will get replicated to DR cluster - /gpfs/drfs1/secondary1 directory.

