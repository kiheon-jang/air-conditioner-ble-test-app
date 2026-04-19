
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  FlutterBluePlus.set        /*
     If you want to use the MockAdapter for testing, you can uncomment the following line
     and comment out the real adapter in main()
     See /example/lib/mock.dart for more details
    */
    // FlutterBluePlus.set     .setOptions(
    //     options: const FlutterBluePlusOptions(
    //         // autoConnect: false,
    //         // connectionTimeout: 2000,
    //         // writeCharacteristicTimeout: 2000,
    //         // readCharacteristicTimeout: 2000,
    //         // useHiddenServices: true,
    //         // turnScreenOn: true,
    //         // androidFlushCachedServices: true,
    //         // androidScanWindow: 2000,
    //         // androidScanInterval: 1000,
    //         // androidExactScanFilters: true,
    //         // androidUseDefaultErrorHandler: true,
    //         )
    // );
  runApp(const FlutterBluePlusApp());
}

class FlutterBluePlusApp extends StatelessWidget {
  const FlutterBluePlusApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothAdapterState>(
        stream: FlutterBluePlus.adapterState,
        initialData: BluetoothAdapterState.unknown,
        builder: (context, snapshot) {
          final adapterState = snapshot.data;
          if (adapterState == BluetoothAdapterState.on) {
            return const BluetoothOnScreen();
          } else {
            return BluetoothOffScreen(adapterState: adapterState);
          }
        },
      ),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.adapterState}) : super(key: key);

  final BluetoothAdapterState? adapterState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${adapterState != null ? adapterState.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
            if (Theme.of(context).platform == TargetPlatform.android)
              ElevatedButton(
                child: const Text('TURN ON'),
                onPressed: () async {
                  await FlutterBluePlus.turnOn();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class BluetoothOnScreen extends StatefulWidget {
  const BluetoothOnScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothOnScreen> createState() => _BluetoothOnScreenState();
}

class _BluetoothOnScreenState extends State<BluetoothOnScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Android 12+ requires BLUETOOTH_SCAN, BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE
    // Location permission is also often required for BLE scanning
    // flutter_blue_plus handles requesting these on Android automatically.
    // On iOS, you need to configure Info.plist as per the Obsidian document.
  }

  void _startScan() async {
    setState(() {
      _devices = [];
      _isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (!_devices.contains(r.device)) {
            setState(() {
              _devices.add(r.device);
            });
          }
        }
      });

      FlutterBluePlus.isScanning.listen((isScanning) {
        setState(() {
          _isScanning = isScanning;
        });
      });
    } catch (e) {
      print("Error starting scan: $e");
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE AC Test App'),
        actions: <Widget>[
          ElevatedButton(
            child: Text(_isScanning ? 'STOP SCAN' : 'START SCAN'),
            onPressed: _isScanning ? _stopScan : _startScan,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return DeviceTile(device: device);
        },
      ),
    );
  }
}

class DeviceTile extends StatefulWidget {
  const DeviceTile({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  State<DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<DeviceTile> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    widget.device.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });
    try {
      await widget.device.connect();
      _services = await widget.device.discoverServices();
      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      print("Error connecting to device: $e");
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.device.disconnect();
    } catch (e) {
      print("Error disconnecting from device: $e");
    }
  }

  Widget _buildConnectButton() {
    if (_isConnecting) {
      return const CircularProgressIndicator();
    }
    if (_connectionState == BluetoothConnectionState.connected) {
      return ElevatedButton(
        child: const Text('DISCONNECT'),
        onPressed: _disconnect,
      );
    } else {
      return ElevatedButton(
        child: const Text('CONNECT'),
        onPressed: _connect,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: Text(widget.device.platformName.isNotEmpty
            ? widget.device.platformName
            : 'Unknown Device'),
        subtitle: Text(widget.device.remoteId.str),
        trailing: _buildConnectButton(),
        children: <Widget>[
          if (_connectionState == BluetoothConnectionState.connected)
            Column(
              children: _services
                  .map(
                    (service) => ServiceTile(
                      service: service,
                      device: widget.device,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  const ServiceTile({Key? key, required this.service, required this.device})
      : super(key: key);

  final BluetoothService service;
  final BluetoothDevice device;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ExpansionTile(
        title: Text('Service: ${service.uuid.str.toUpperCase().substring(4, 8)}'),
        children: service.characteristics
            .map(
              (characteristic) => CharacteristicTile(
                characteristic: characteristic,
                device: device,
              ),
            )
            .toList(),
      ),
    );
  }
}

class CharacteristicTile extends StatefulWidget {
  const CharacteristicTile({
    Key? key,
    required this.characteristic,
    required this.device,
  }) : super(key: key);

  final BluetoothCharacteristic characteristic;
  final BluetoothDevice device;

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int> _value = [];

  Future<void> _readValue() async {
    try {
      final value = await widget.characteristic.read();
      setState(() {
        _value = value;
      });
    } catch (e) {
      print("Error reading characteristic: $e");
    }
  }

  Future<void> _writeValue() async {
    try {
      // For demonstration, write a dummy value (e.g., 1 for ON, 0 for OFF)
      // In a real AC app, you'd send specific commands.
      await widget.characteristic.write([1], withoutResponse: widget.characteristic.properties.writeWithoutResponse);
      print("Value written to characteristic.");
    } catch (e) {
      print("Error writing characteristic: $e");
    }
  }

  Widget _buildButton(
      {required String text, required VoidCallback onPressed, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.characteristic.properties;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Characteristic: ${widget.characteristic.uuid.str.toUpperCase().substring(4, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Value: ${_value.toString()}'),
            Text('Properties: R(${properties.read}) W(${properties.write}) N(${properties.notify}) I(${properties.indicate})'),
            Row(
              children: <Widget>[
                if (properties.read) _buildButton(text: 'READ', onPressed: _readValue),
                if (properties.write || properties.writeWithoutResponse)
                  _buildButton(text: 'WRITE (dummy)', onPressed: _writeValue),
                if (properties.notify || properties.indicate)
                  _buildButton(
                    text: 'NOTIFY (toggle)',
                    onPressed: () async {
                      try {
                        await widget.characteristic.setNotifyValue(!widget.characteristic.isNotifying);
                        setState(() {}); // Update UI to reflect notifying state
                      } catch (e) {
                        print("Error setting notify value: $e");
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
