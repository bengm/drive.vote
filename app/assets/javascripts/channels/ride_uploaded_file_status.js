// app/assets/javascripts/channels/ride_uploaded_file_status.js

//= require cable
//= require_self
//= require_tree .

function createRideUploadedFileStatusChannel(rideUploadedFileId, connectedCallBack, disconnectedCallBack, receiveCallBack) {
    "use strict";

    if (App.rideUploadedFileStatus) {
        App.cable.subscriptions.remove(App.ridezone)
    }
    App.rideUploadedFileStatus = App.cable.subscriptions.create({channel: 'RideUploadedFileStatusChannel', id: rideUploadedFileId}, {
        // Built-in, called by framework whenever connection is established
        connected: function (data) {
            console.log('RideUploadedFileStatusChannel connection to server established: '+rideUploadedFileId); // debugging
            connectedCallBack();
        },

        // Built-in, called by framework whenever connection is bro
        // ken
        disconnected: function() {
            console.log('RideUploadedFileStatusChannel connection to server disconnected: '+rideUploadedFileId); // debugging
            connectedCallBack();
        },

        // Built-in, called by framework whenever data arrives from server
        received: function(data) {
            debugger;
            console.log('RideUploadedFileStatusChannel: '+rideUploadedFileId + ' dryRun?: ' + data.dry_run); // debugging
            receiveCallBack(data);
        }

    });
}
