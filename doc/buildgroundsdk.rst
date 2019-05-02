.. _repo install:

Install and build GroundSdk
===========================

Environment setup
-----------------
Download and install the latest Xcode from App Store Application

.. note:: GroundSdk has been successfully tested with Xcode 10.2, Swift 4.2
    and Mac OS Mojave 10.14

Install Homebrew

.. code-block:: console

    $ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

Install the required tools using Homebrew

.. code-block:: console

    $ brew install bash-completion git xctool pkgconfig repo python3 cmake autoconf automake libtool

Install the following Python module

.. code-block:: console

    $ pip3 install requests

Configure git with your real name and email address

.. code-block:: console

    $ git config --global user.name "Your Name"
    $ git config --global user.email "you@example.com"

Download GroundSdk
------------------
Create your working directory

.. code-block:: console

    $ mkdir groundsdk
    $ cd groundsdk

Initialize Repo in your working directory

.. code-block:: console

    $ repo init -u https://github.com/Parrot-Developers/groundsdk-manifest

.. note:: You can learn how to use Repo on the `command reference page`_

Download the GroundSdk source tree

.. code-block:: console

    $ repo sync

Xcode configuration
-------------------

Open project to install automatically last components of Xcode

.. code-block:: console

    $  open ./products/groundsdk/ios/xcode/groundsdk.xcworkspace/

Connect your Apple developer account and select your provisioning profile

Build and run GroundSdk Demo
----------------------------

#. Build GroundSdk Demo for iOS device

.. code-block:: console

    # the build script will ask you to enter your password session a few times
    $ ./build.sh -p groundsdk-ios -t build -j

.. note:: To know more about building options

    .. code-block:: console

        $ ./build.sh -p groundsdk-ios -t

.. note:: Build GroundSdk Demo for Simulator

    .. code-block:: console

        $ ./build.sh -p groundsdk-ios_sim -t build -j

2. Connect an iOS device to your computer
#. Go back to Xcode
#. Select iOS device
#. Click on Build and then run the current scheme

Connect to your drone
---------------------
#. Switch on your drone
#. Open wifi settings on your iOS device
#. Select your drone's wifi access point (e.g. ANAFI-xxxxxxx)
#. Enter wifi password
#. Open Ground SDK Demo app
#. Your drone should appear in the list, select it
#. Click on Connect

.. _command reference page: https://source.android.com/setup/develop/repo
