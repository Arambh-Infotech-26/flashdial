package com.at.flashdial

import android.telecom.Call
import android.telecom.CallEndpoint
import android.telecom.InCallService

class CallInCallService : InCallService() {
    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        CallManager.add(this, call)
    }

    override fun onCallRemoved(call: Call) {
        CallManager.remove(call)
        super.onCallRemoved(call)
    }

    override fun onAvailableCallEndpointsChanged(availableEndpoints: MutableList<CallEndpoint>) {
        super.onAvailableCallEndpointsChanged(availableEndpoints)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            CallManager.updateAvailableEndpoints(availableEndpoints)
        }
    }

    override fun onDestroy() {
        CallManager.detach(this)
        super.onDestroy()
    }
}
