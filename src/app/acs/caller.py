from aiohttp import web
import json
from logging import INFO
from azure.eventgrid import EventGridEvent, SystemEventNames
from azure.core.messaging import CloudEvent
from typing import List, Optional, Union, TYPE_CHECKING
from azure.communication.callautomation import (
    CallAutomationClient,
    CallConnectionClient,
    PhoneNumberIdentifier,
    MediaStreamingOptions,
    MediaStreamingTransportType,
    MediaStreamingContentType,
    RecognizeInputType,
    MicrosoftTeamsUserIdentifier,
    MediaStreamingAudioChannelType,
    CallInvite,
    RecognitionChoice,
    AudioFormat,
    DtmfTone,
    VoiceKind,
    FileSource,
    TextSource
)
from azure.communication.callautomation.aio import CallAutomationClient
from azure.communication.phonenumbers import PhoneNumbersClient,PhoneNumberCapabilityType, PhoneNumberAssignmentType, PhoneNumberType, PhoneNumberCapabilities
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

        websocket_url = 'wss://' + self.acs_callback_path + '/realtime-acs'

        media_streaming_options = MediaStreamingOptions(
                        transport_url=websocket_url,
                        transport_type=MediaStreamingTransportType.WEBSOCKET,
                        content_type=MediaStreamingContentType.AUDIO,
                        audio_channel_type=MediaStreamingAudioChannelType.MIXED,
                        start_media_streaming=True,
                        enable_bidirectional=True,
                        audio_format=AudioFormat.PCM24_K_MONO)

        call_connection_properties = await self.call_automation_client.create_call(self.target_participant, 
                                                                    'https://' + self.acs_callback_path + '/acs',
                                                                    source_caller_id_number=self.source_caller,
                                                                    media_streaming = media_streaming_options)
        
        call_connection = {
            'call_established': True,
            'connection_id': call_connection_properties.call_connection_id
        }

        return web.json_response(call_connection)

    async def _outbound_call_handler(self, request):
        print("Outbound call handler")
        cloudevent = await request.json()
        for event_dict in cloudevent:
            # Parsing callback events
            event = CloudEvent.from_dict(event_dict)
            call_connection_id = event.data['callConnectionId']
            print(f"{event.type} event received for call connection id: {call_connection_id}")
            call_connection_client = self.call_automation_client.get_call_connection(call_connection_id)
            # target_participant = PhoneNumberIdentifier(self.target_number)
            if event.type == "Microsoft.Communication.CallConnected":
                print("Call connected")
                print(call_connection_id)
                call_connection_properties = call_connection_client.get_call_properties()
                print(call_connection_properties)
                media_streaming_subscription = call_connection_properties.media_streaming_subscription
                print(media_streaming_subscription)
                return web.Response(status=200)
        
        return web.Response(status=500)

    async def _get_source_number(self):
       return self.source_number

    def attach_to_app(self, app, path):
        app.router.add_post(path, self._outbound_call_handler)
