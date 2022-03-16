# Packer templates

Hasicorp [Packer](https://www.packer.io/) templates for building Windows Server and Windows 10 images for Windows Virtual Desktop, Citrix Cloud etc. in Azure. Images are built via Azure DevOps and stored in a [Shared Image Library](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries).

Leverages [Evergreen](https://stealthpuppy.com/evergreen) to create images with the latest application versions so that each image is always up to date.

Outputs reports in markdown format for basic tracking of image updates: [stealthpuppy.com/packer](https://stealthpuppy.com/packer).
