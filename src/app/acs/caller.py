
from logging import INFO
from azure.eventgrid import EventGridEvent, SystemEventNames
from azure.core.messaging import CloudEvent
from typing import List, Optional, Union, TYPE_CHECKING
from azure.communication.callautomation import (
    CallAutomationClient,
    CallConnectionClient,
    PhoneNumberIdentifier,
    RecognizeInputType,
    MicrosoftTeamsUserIdentifier,
    CallInvite,
    RecognitionChoice,
    DtmfTone,
    VoiceKind,
    FileSource,
    TextSource)
import json
from aiohttp import web
import requests

class OutboundCall:
    source_number: str
    acs_connection_string: str
    acs_callback_path: str

    def __init__(self, source_number:str, acs_connection_string: str, acs_callback_path: str):
        self.source_number = source_number
        self.acs_connection_string = acs_connection_string
        self.acs_callback_path = acs_callback_path
    
    async def call(self, target_number: str):
        self.call_automation_client = CallAutomationClient.from_connection_string(self.acs_connection_string)
        self.target_participant = PhoneNumberIdentifier(target_number)
        self.source_caller = PhoneNumberIdentifier(self.source_number)
        call_connection_properties = self.call_automation_client.create_call(self.target_participant, 
                                                                    self.acs_callback_path,
                                                                    source_caller_id_number=self.source_caller)

    async def _outbound_call_handler(self, request):
        print("Outbound call handler")
        cloudevent = await request.json()
        for event_dict in cloudevent:
            # Parsing callback events
            event = CloudEvent.from_dict(event_dict)
            call_connection_id = event.data['callConnectionId']
            print("%s event received for call connection id: %s", event.type, call_connection_id)
            call_connection_client = self.call_automation_client.get_call_connection(call_connection_id)
            # target_participant = PhoneNumberIdentifier(self.target_number)
            if event.type == "Microsoft.Communication.CallConnected":
                print("Call connected")
                print(call_connection_id)

        return web.Response(status=200)


    def attach_to_app(self, app, path):
        app.router.add_post(path, self._outbound_call_handler)
