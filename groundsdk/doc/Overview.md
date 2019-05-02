GroundSdk
=========

Overview
--------

GoundSdk is composed of 3 modules:
- GroundSdk: Sdk API and its implementation.
- ArsdkEngine: Sdk engines based on ARSDK
- SdkCore: native code wrapper

Application should only import GroundSdk module. All types (Classes, Protocols, Enum,…) ending with “Core” are internal
and should not be used by the application

Main entry point is the class `GroundSdk`. Application can create as many instance of this class as required. Sdk is
started when the first GroundSdk instance is created and stopped when the last strong reference on a GroundSdk
instance is lost.

`GroundSdk` class provides API to access `Drone` and `RemoteControl` objects. `GroundSdk` keep a list of known and
available drones and remote control.

Drone and RemoteControl classes
-------------------------------

The `Drone` class represents a drone (any model). The  `RemoteControl` class represent a remote control (i.e MPP) of
any model. Both are uniquely identified by a persistent UID, and have basic properties like their name and state.

Those 2 classes are also containers of `Component` objects representing parts of the drone or remote control. A
component has properties storing the current state/info of the represented element and function to act on it.

There are 3 types of components:
- `Instrument`: components that provides telemetry informations.
- `PilotingItf`: components that allows to pilot the drone.
- `Peripheral`: components for accessory functions.

Each drone and remote control have a subset of all available components. For example if a drone has a GPS it will
contains the `Gps` instrument.

Some components are available when the drone is disconnected, some only when the drone or remote control is connected.

Facilities
----------

`GroundSdk` provides a set of global services component that application can access. An example of facility is
`UpdateManager` that handle the download of firmware updates from a cloud server.

One of the main facility is `AutoConnection`. This facility connects a remote control or a drone as soon as
it's available.

Notifications
-------------

Application can receive a notification when properties of a component changes, by using functions that takes a closure
parameter and returns a `Ref<T>`.
With those function the closure is called each time properties of a component changes **as long as there is a strong
reference on the returned Ref<T>.***

Configuration
-------------

GroundSdk can be configured by adding entries to the info.plist file. See `GroundSdkConfig` for available keys.




