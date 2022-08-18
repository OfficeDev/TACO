Function Get-jsonSchema (){
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string[]]$schemaName
    )

Switch ($schemaName) {

# JSON schema definition for Set-CallQueueTimeOutAction    
'Set-CallQueueTimeOutAction' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueTimeOutAction API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "TimeoutAction": {
                "type": "string",
                "title": "Specifies the action which needs to take place when the queue timed out",
                "examples": [
                    "Person in Organization",
                    "Voice App",
                    "External Phone Number",
			        "Voicemail"
                ]
            },
            "TimeoutTarget": {
                "type": ["number","null"],
                "title": "Specifies where to send the call to, this can be either a UPN or phonenumber",
                "examples": [
                    "+31301234567",
			        "contoso-it-helpdesk@contoso.com"
                ]
            },
            "TimeOutThreshold": {
                "type": "int",
                "title": "timeout threshold in seconds",
                "examples": [
                    "60"
                ]
            },    			
            "TimeoutVoicemailTarget": {
                "type": "string",
                "title": "Specifies the O365 group where the voicemail needs to be delivered",
                "examples": [
                    "it-helpdesk@contoso.com"
                ]
            },             
            "TimeoutVoiceMailTranscription": {
                "type": "boolean",
                "title": "Specifies if voicemail transcription is enabled or not",
                "examples": [
                    true,
                    false
                ]
            },
            "TimeoutVoicemailTTSPrompt": {
                "type": "string",
                "title": "Specifies the voicemail greeting TTS",
                "examples": [
                    "Welcome to the second line helpdesk, since the expected wait time is longer as expected you will now have the option to leave a voicemail"
                ]
            },
            "TimeoutVoicemailAudioPrompt": {
                "type": "string",
                "title": "Specifies the voicemail greeting audio file",
                "examples": [
                    "prompt.mp3"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                                                     
        }
    }
'@ }

# JSON schema definition for Set-CallQueueOverFlowAction    
'Set-CallQueueOverFlowAction' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueOverFlowAction API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "OverflowAction": {
                "type": "string",
                "title": "Specifies the action which needs to take place when the queue timed out",
                "examples": [
                    "Person in Organization",
                    "Voice App",
                    "External Phone Number",
			  "Voicemail"
                ]
            },
            "OverflowTarget": {
                "type": ["number","null"],
                "title": "Specifies where to send the call to, this can be either a UPN or phonenumber",
                "examples": [
                    "+31301234567",
			        "contoso-it-helpdesk@contoso.com"
                ]
            },
            "OverflowThreshold": {
                "type": "int",
                "title": "overflow threshold",
                "examples": [
                    "10"
                ]
            }, 			
            "OverflowVoicemailTarget": {
                "type": "string",
                "title": "Specifies the O365 group where the voicemail needs to be delivered",
                "examples": [
                    "it-helpdesk@contoso.com"
                ]
            },              
            "OverflowVoicemailTranscription": {
                "type": "boolean",
                "title": "Specifies voice transcription should be on or off",
                "examples": [
                    true,
                    false
                ]
            },
            "OverflowVoicemailTTSPrompt": {
                "type": "string",
                "title": "Specifies the voicemail greeting",
                "examples": [
                    "Welcome to the second line helpdesk, since the expected wait time is longer as expected you will now have the option to leave a voicemail"
                ]
            },
            "OverflowVoicemailAudioPrompt": {
                "type": "string",
                "title": "Specifies the voicemail greeting audio file",
                "examples": [
                    "greeting.mp3"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                         
        }
    }
'@ }

# JSON schema definition for Set-CallQueueOverFlowThreshold    
'Set-CallQueueOverFlowThreshold' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueTimeOutAction API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "OverflowThreshold": {
                "type": "int",
                "title": " Any integer value between 0 and 200, inclusive. A value of 0 causes calls not to reach agents and the overflow action to be taken immediately.",
                "examples": [
                    "20"
                ]
            }   
        }
    }
'@ }

# JSON schema definition for Set-CallQueueTimeOutThreshold    
'Set-CallQueueTimeOutThreshold' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueTimeOutAction API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "TimeOutThreshold": {
                "type": "int",
                "title": "Any integer value between 0 and 2700 seconds (inclusive), and is rounded to the nearest 15th interval",
                "examples": [
                    "20"
                ]
            }   
        }
    }
'@ }

# JSON schema definition for Set-CallQueueAgentAlertTime 
'Set-CallQueueAgentAlertTime' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueAgentAlertTime API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "AgentAlertTime": {
                "type": "integer",
                "title": "Agent Alert Time",
                "examples": [
                    "30"
                ]
            }              
        }
    }
'@ }

# JSON schema definition for Set-CallQueueGreeting 
'Set-CallQueueGreeting' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueGreeting API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "Greeting": {
                "type": "string",
                "title": "Filename of greeting prompt",
                "examples": [
                    "greeting.mp3"
                ]
            } ,
            "GreetingType": {
                "type": "string",
                "title": "Either default or custom prompt",
                "examples": [
                    "Default",
                    "Custom"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                            
        }
    }
'@ }

# JSON schema definition for Set-CallQueueMusicOnHold 
'Set-CallQueueMusicOnHold' { Return @'
    {
        "type": "object",
        "title": " Set-CallQueueMusicOnHold API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "MoH": {
                "type": "string",
                "title": "Filename of MoH",
                "examples": [
                    "MoH.mp3"
                ]
            } ,
            "MoHType": {
                "type": "string",
                "title": "Either default or custom",
                "examples": [
                    "Default",
                    "Custom"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                            
        }
    }
'@ }

# JSON schema definition for Set-AutoAttendantCallRouting 
'Set-AutoAttendantCallRouting' { Return @'
    {
        "type": "object",
        "title": " Set-AutoAttendantCallRouting API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the auto attendant",
                "examples": [
                    "contoso it helpdesk auto attendant"
                ]
            },  
            "RedirectTarget": {
                "type": "string",
                "title": "Target to redirect call to",
                "examples": [
                    "adele.vance@contoso.com",
                    "it-helpdesk-call-queue@contoso.com"
                ]
            },
            "RedirectTargetType": {
                "type": "string",
                "title": "Target type to redirect call to",
                "examples": [
                    "Disconnect",
                    "Redirect: Person in organization"
                ]
            },
            "RedirectTargetVoicemailPromptSuppression": {
                "type": "boolean",
                "title": "Target type to redirect call to",
                "examples": [
                    true,
                    false
                ]
            },
            "RoutingHours": {
                "type": "string",
                "title": "timeframe for which to change routing business or after business hours",
                "examples": [
                    "business hours",
                    "after business hours"
                ]
            }                            
        }
    }
'@ }

# JSON schema definition for Set-AutoAttendantGreeting
'Set-AutoAttendantGreeting' { Return @'
    {
        "type": "object",
        "title": " Set-AutoAttendantGreeting API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the auto attendant",
                "examples": [
                    "contoso it helpdesk auto attendant"
                ]
            },
            "GreetingHours": {
                "type": "string",
                "title": "Either during business hours or outside of business hours",
                "examples": [
                    "business hours"
                ]
            },   
            "GreetingTypeBusinessHours": {
                "type": "string",
                "title": "Type of greeting",
                "examples": [
                    "audio",
                    "text"
                ]
            },
            "GreetingTextBusinessHours": {
                "type": "string",
                "title": "Text in case greeting type is set to text",
                "examples": [
                    "Welcome to Contoso IT"
                ]
            }  ,
            "GreetingAudioBusinessHours": {
                "type": "string",
                "title": "Audio file name in case greeting type is set to audio",
                "examples": [
                    "contoso-it.mp3"
                ]
            },
            "GreetingTypeAfterBusinessHours": {
                "type": "string",
                "title": "Type of greeting",
                "examples": [
                    "audio",
                    "text"
                ]
            },
            "GreetingTextAfterBusinessHours": {
                "type": "string",
                "title": "Text in case greeting type is set to text",
                "examples": [
                    "Welcome to Contoso IT"
                ]
            }  ,
            "GreetingAudioAfterBusinessHours": {
                "type": "string",
                "title": "Audio file name in case greeting type is set to audio",
                "examples": [
                    "contoso-it.mp3"
                ]
            },
            "GreetingHours": {
                "type": "string",
                "title": "timeframe for which to change the greeting business or after business hours",
                "examples": [
                    "business hours",
                    "after business hours"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                                                     
        }
    }
'@ }

# JSON schema definition for Set-AutoAttendantBusinessHours
'Set-AutoAttendantBusinessHours' { Return @'
    {
        "type": "object",
        "title": " Set-AutoAttendantBusinessHours API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the auto attendant",
                "examples": [
                    "contoso it helpdesk auto attendant"
                ]
            },
            "days": {
                "Monday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    }                                        
                },
               "Tuesday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    }                                        
                },
               "Wednesday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    }                                        
                },
               "Thursday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
               "Friday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
               "Saturday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
               "Sunday": {
                    "StartTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime1" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 1",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "StartTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },
                    "EndTime2" :
                    {
                        "type": "string",
                        "title": "Specifies the starttime of timerange 2",
                        "examples": [
                        "12:00"
                        ]  
                    },                                                                                                    
                }                                                
            }                          
        }
    }
'@ }

# JSON schema definition for Add-AutoAttendantHoliday 
'Add-AutoAttendantHoliday' { Return @'
    {
        "type": "object",
        "title": " Add-AutoAttendantHoliday API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the auto attendant",
                "examples": [
                    "contoso it helpdesk auto attendant"
                ]
            },  
            "HolidayName": {
                "type": "string",
                "title": "Name of holidau",
                "examples": [
                    "1st Christmas day"
                ]
            },
            "HolidayStartDate": {
                "type": "string",
                "title": "Start date of holiday",
                "examples": [
                    "25-12-2022"
                ]
            },
            "HolidayEndDate": {
                "type": "string",
                "title": "End date of holiday",
                "examples": [
                    "26-12-2022"
                ]
            },
            "HolidayGreetingType": {
                "type": "string",
                "title": "Type of greeting",
                "examples": [
                    "audio",
                    "text"
                ]
            },
            "HolidayGreetingAudio": {
                "type": "string",
                "title": "Greeting audio file",
                "examples": [
                    "christmas.mp3"
                ]
            },
            "HolidayGreetingText": {
                "type": "string",
                "title": "Greeting text",
                "examples": [
                    "We wish you a merry Christmas"
                ]
            },
            "HolidayRedirectTarget": {
                "type": "string",
                "title": "Target to which to forward the call",
                "examples": [
                    "adele.vance@myuclab.nl"
                ]
            }, 
            "HolidayRedirectType": {
                "type": "string",
                "title": "Target type to which to forward the call",
                "examples": [
                    "Disconnect",
                    "Redirect: Person in organization"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                                                                      
        }
    }
'@ }

# JSON schema definition for Set-AutoAttendantHoliday 
'Set-AutoAttendantHoliday' { Return @'
    {
        "type": "object",
        "title": " Set-AutoAttendantHoliday API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the auto attendant",
                "examples": [
                    "contoso it helpdesk auto attendant"
                ]
            },  
            "HolidayName": {
                "type": "string",
                "title": "Name of holidau",
                "examples": [
                    "1st Christmas day"
                ]
            },
            "HolidayStartDate": {
                "type": "string",
                "title": "Start date of holiday",
                "examples": [
                    "25-12-2022"
                ]
            },
            "HolidayEndDate": {
                "type": "string",
                "title": "End date of holiday",
                "examples": [
                    "26-12-2022"
                ]
            },
            "HolidayGreetingType": {
                "type": "string",
                "title": "Type of greeting",
                "examples": [
                    "audio",
                    "text"
                ]
            },
            "HolidayGreetingAudio": {
                "type": "string",
                "title": "Greeting audio file",
                "examples": [
                    "christmas.mp3"
                ]
            },
            "HolidayGreetingText": {
                "type": "string",
                "title": "Greeting text",
                "examples": [
                    "We wish you a merry Christmas"
                ]
            },
            "HolidayRedirectTarget": {
                "type": "string",
                "title": "Target to which to forward the call",
                "examples": [
                    "adele.vance@myuclab.nl"
                ]
            }, 
            "HolidayRedirectType": {
                "type": "string",
                "title": "Target type to which to forward the call",
                "examples": [
                    "Disconnect",
                    "Redirect: Person in organization"
                ]
            },
            "SPSite": {
                "type": "string",
                "title": "SharePoint site containing audio files",
                "examples": [
                    "TeamsAAandCQManagement"
                ]
            }                                                                     
        }
    }
'@ }

# JSON schema definition for Remove-AutoAttendantHoliday 
'Remove-AutoAttendantHoliday' { Return @'
    {
        "type": "object",
        "title": "Set-CallQueueAgentAlertTime API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            },  
            "HolidayName": {
                "type": "string",
                "title": "Holiday name",
                "examples": [
                    "1st Christmas day"
                ]
            }              
        }
    }
'@ }

# JSON schema definition for Export-AutoAttendant    
'Export-AutoAttendant' { Return @'
    {
        "type": "object",
        "title": "Export-AutoAttendant API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the auto attendant",
                "examples": [
                    "contoso it"
                ]
            } 
        }
    }
'@ }

# JSON schema definition for Export-CallQueue    
'Export-CallQueue' { Return @'
    {
        "type": "object",
        "title": "Export-CallQueue API JSON body definition",  
        "required": [
            "Identity"
        ],
        "properties": {
            "Identity": {
                "type": "string",
                "title": "Specifies the identity of the call queue",
                "examples": [
                    "contoso it helpdesk queue"
                ]
            } 
        }
    }
'@ }

# No match found - Return empty JSON definition  
Default { Return @'
    {}
'@ }

} 
}