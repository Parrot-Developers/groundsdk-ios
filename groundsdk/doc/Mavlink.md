FlightPlan Mavlink Generation
======================

In this release, GroundSdk doesn't provide Swift API to generate FlightPlan Mavlink file.

As a temporary solution, SdkCore.framework includes `libARMavlink` library from ARSDK 3. This library can be use from
Objective-C by using the following import:

    #import "SdkCore/libARMavlink_ios.h"

