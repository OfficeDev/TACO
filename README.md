# Microsoft Teams AA/CQ Orchestrator App


| [Solution overview](https://github.com/OfficeDev/TACO/wiki/1.-Solution-overview) |[Deployment guide](https://github.com/OfficeDev/TACO/wiki/2.-Deployment) | [Configuration guide](https://github.com/OfficeDev/TACO/wiki/3.-Configuration) | [FAQ](https://github.com/OfficeDev/TACO/wiki/4.-FAQ) | [Support](https://github.com/OfficeDev/TACO/blob/main/SUPPORT.md) |
| ---- | ---- | ---- | ---- | ---- |

A delegated Admin application for Auto Attendant and Call Queue management

<img src="./Media/taco-logo.png" height="140">



## What's in it for you

Microsoft Teams provides an administration portal (Teams Admin Center (TAC)) to manage the different telephony services including auto attendants and call queues for the organization. To access this portal, you need to assign one of the administrator roles defined [here](https://docs.microsoft.com/en-us/MicrosoftTeams/using-admin-roles). To manage the auto attendants and call queues, the minimum required  role is "Teams Administrator" - This role is then applied at the scope of the Azure AD tenant, meaning all users in your organization.

Currently the Teams Admin Center does not provide the ability to delegate access to for example the owners of auto attendants to change the greeting or change business hours. This can only be changed by a user who has access to the Teams Admin Center. This application will provide organizations a method to delegate the administration of auto attendants and call queues.

As of today, this application supports the following scenarios:
* Auto Attendant
 * Change greeting
 * Change call routing options (except changing the menu options)
 * Set business hours (max 1 additional timeslot per day)
 * Change holiday call settings
* Call queue
 * Change greeting
 * Change music on hold
 * Change call overflow handling
 * Change call timeout handling

The architecture of this solution can be adapted to support other scenarios that require delegated admin management of Teams phone system or any other feature accessible via PowerShell cmdlet or even MS Graph API. 

Here is the application running in Microsoft Teams

<!-- <p align="center">
    <img src="./Media/AAandCQManagement.jpg" alt="Microsoft Teams AA/CQ Orchestrator screenshot" width="600"/>
</p> -->

![Microsoft Teams AA/CQ Orchestrator screenshot](./Media/AAandCQManagement.jpg)

If you want to start using the solution yourself review the Wiki for the deployment and configuration steps.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.


## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

## Reference documentation

### Microsoft Teams PowerShell module
- [PowerShell Gallery | MicrosoftTeams](https://www.powershellgallery.com/profiles/MicrosoftTeams/)

### Azure
- [Azure Functions PowerShell developer guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell)
