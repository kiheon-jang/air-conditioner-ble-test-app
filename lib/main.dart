
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// permission_handler 패키지를 사용하려면 pubspec.yaml에 추가하고 import 해야 합니다.
// import 'package:permission_handler/permission_handler.dart';

// 에어컨 제어를 위한 가상의 BLE 서비스 및 캐릭터리스틱 UUID 정의
// 실제 장치와 연동 시, 제조업체에서 제공하는 정확한 UUID로 변경해야 합니다.
class AcBleUuids {
  // 에어컨 제어 서비스 UUID
  static Guid AC_CONTROL_SERVICE_UUID = Guid("4A987654-2000-4780-877C-000000000001");
  // 전원 상태 캐릭터리스틱 (Read, Write, Notify)
  static Guid POWER_STATE_CHARACTERISTIC_UUID = Guid("4A987654-2000-4780-877C-000000000002");
  // 동작 모드 캐릭터리스틱 (Read, Write, Notify)
  static Guid OPERATION_MODE_CHARACTERISTIC_UUID = Guid("4A987654-2000-4780-877C-000000000003");
  // 목표 온도 캐릭터리스틱 (Read, Write, Notify)
  static Guid TARGET_TEMPERATURE_CHARACTERISTIC_UUID = Guid("4A987654-2000-4780-877C-000000000004");
  // 현재 실내 온도 캐릭터리스틱 (Read, Notify)
  static Guid CURRENT_ROOM_TEMPERATURE_CHARACTERISTIC_UUID = Guid("4A987654-2000-4780-877C-000000000005");
  // 팬 속도 캐릭터리스틱 (Read, Write, Notify)
  static Guid FAN_SPEED_CHARACTERISTIC_UUID = Guid("4A987654-2000-4780-877C-000000000006");
}

void main() {
  FlutterBluePlus.setOptions(
    options: const FlutterBluePlusOptions(
      // connectionTimeout: 2000, // 연결 타임아웃 설정 (선택 사항)
    ),
  );
  runApp(const FlutterBluePlusApp());
}

class FlutterBluePlusApp extends StatelessWidget {
  const FlutterBluePlusApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE AC Control Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
                child: const Text('TURN ON BLUETOOTH'),
                onPressed: () async {
                  await FlutterBluePlus.turnOn();
                },
              ),
            // iOS에서는 사용자가 직접 설정에서 블루투스를 켜야 합니다.
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
    // flutter_blue_plus handles requesting these on Android automatically
    // when you start scanning or connecting.
    // However, for more explicit control and better UX, consider using
    // a package like `permission_handler` to request permissions beforehand.

    // 예시: permission_handler 사용 (주석 해제 시)
    /*
    var bluetoothScanStatus = await Permission.bluetoothScan.status;
    var bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    var locationWhenInUseStatus = await Permission.locationWhenInUse.status;

    if (bluetoothScanStatus.isDenied || bluetoothConnectStatus.isDenied || locationWhenInUseStatus.isDenied) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    }
    */
  }

  void _startScan() async {
    setState(() {
      _devices = [];
      _isScanning = true;
    });

    try {
      // 특정 서비스 UUID로 필터링하여 스캔 효율화
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        // withServices: [AcBleUuids.AC_CONTROL_SERVICE_UUID], // 에어컨 서비스 UUID로 필터링 (선택 사항)
      );
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // 중복 장치 방지 및 이름 없는 장치 필터링 (선택 사항)
          if (!_devices.any((d) => d.remoteId == r.device.remoteId) && r.device.platformName.isNotEmpty) {
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
      // 사용자에게 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BLE 스캔 오류: $e')),
      );
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
        title: const Text('BLE AC Control Test'),
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
  // 재연결 로직을 위한 변수
  int _reconnectionAttempt = 0;
  static const int MAX_RECONNECTION_ATTEMPTS = 5;
  static const Duration RECONNECTION_DELAY = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    // 연결 상태 변화를 감지하고 재연결 로직 구현
    widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
        if (state == BluetoothConnectionState.disconnected) {
          print("Device disconnected: ${widget.device.platformName}. Attempting reconnection...");
          _attemptReconnection();
        }
      }
    });
  }

  Future<void> _attemptReconnection() async {
    if (_reconnectionAttempt < MAX_RECONNECTION_ATTEMPTS) {
      _reconnectionAttempt++;
      print("Reconnection attempt $_reconnectionAttempt for ${widget.device.platformName} after ${RECONNECTION_DELAY.inSeconds} seconds.");
      await Future.delayed(RECONNECTION_DELAY);
      if (_connectionState == BluetoothConnectionState.disconnected) {
        await _connect(isReconnecting: true);
      }
    } else {
      print("Max reconnection attempts reached for ${widget.device.platformName}. Giving up.");
      _reconnectionAttempt = 0; // 다음 수동 연결 시도를 위해 초기화
    }
  }

  Future<void> _connect({bool isReconnecting = false}) async {
    setState(() {
      _isConnecting = true;
    });
    try {
      // 연결 타임아웃을 FlutterBluePlusOptions에서 설정하거나 여기서 직접 설정할 수 있습니다.
      await widget.device.connect();
      _services = await widget.device.discoverServices();
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _reconnectionAttempt = 0; // 성공적으로 연결되면 재연결 시도 횟수 초기화
        });
      }
      print("Device connected: ${widget.device.platformName}");
    } catch (e) {
      print("Error connecting to device: $e");
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
      // 연결 실패 시 재연결 시도
      if (!isReconnecting) {
        // 첫 연결 시도 실패 시에만 스낵바 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('장치 연결 실패: ${widget.device.platformName}')),
        );
      }
      // 재연결 로직은 _attemptReconnection에서 호출되므로 여기서 직접 재호출하지 않습니다.
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.device.disconnect();\n      print("Device disconnected: ${widget.device.platformName}");
    } catch (e) {
      print("Error disconnecting from device: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('장치 연결 해제 실패: $e')),
      );
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
        onPressed: () => _connect(),
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
            ),\n        ],
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  const ServiceTile({Key? key, required this.service, required this.device})
      : super(key: key);

  final BluetoothService service;
  final BluetoothDevice device;

  // 서비스 UUID에 따라 사람이 읽을 수 있는 이름 반환
  String getServiceName(Guid uuid) {
    if (uuid == AcBleUuids.AC_CONTROL_SERVICE_UUID) {
      return "AC Control Service";
    }
    // 기타 표준 서비스 (예: Generic Access, Generic Attribute) 처리
    if (uuid == Guid("00001800-0000-1000-8000-00805f9b34fb")) return "Generic Access";
    if (uuid == Guid("00001801-0000-1000-8000-00805f9b34fb")) return "Generic Attribute";
    return service.uuid.str.toUpperCase().substring(4, 8); // 간략화된 UUID
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ExpansionTile(
        title: Text('Service: ${getServiceName(service.uuid)}'),
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

  @override
  void initState() {
    super.initState();
    if (widget.characteristic.properties.notify || widget.characteristic.properties.indicate) {
      widget.characteristic.lastValueStream.listen((value) {
        if (mounted) {
          setState(() {
            _value = value;
          });
        }
      });
    }
  }

  // 캐릭터리스틱 UUID에 따라 사람이 읽을 수 있는 이름 반환
  String getCharacteristicName(Guid uuid) {
    if (uuid == AcBleUuids.POWER_STATE_CHARACTERISTIC_UUID) return "Power State";
    if (uuid == AcBleUuids.OPERATION_MODE_CHARACTERISTIC_UUID) return "Operation Mode";
    if (uuid == AcBleUuids.TARGET_TEMPERATURE_CHARACTERISTIC_UUID) return "Target Temperature";
    if (uuid == AcBleUuids.CURRENT_ROOM_TEMPERATURE_CHARACTERISTIC_UUID) return "Current Room Temperature";
    if (uuid == AcBleUuids.FAN_SPEED_CHARACTERISTIC_UUID) return "Fan Speed";
    return widget.characteristic.uuid.str.toUpperCase().substring(4, 8); // 간략화된 UUID
  }

  Future<void> _readValue() async {
    try {
      final value = await widget.characteristic.read();
      if (mounted) {
        setState(() {
          _value = value;
        });
      }
      print("Read value from ${getCharacteristicName(widget.characteristic.uuid)}: $value");
    } catch (e) {
      print("Error reading characteristic: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('캐릭터리스틱 읽기 실패: $e')),
      );
    }
  }

  Future<void> _writeValue(List<int> value) async {
    try {
      await widget.characteristic.write(value, withoutResponse: widget.characteristic.properties.writeWithoutResponse);
      print("Value written to ${getCharacteristicName(widget.characteristic.uuid)}: $value");
      // 값이 변경되었을 수 있으므로 즉시 읽기 시도 (Notify가 아닐 경우)
      if (!widget.characteristic.properties.notify && !widget.characteristic.properties.indicate) {
        _readValue();
      }
    } catch (e) {
      print("Error writing characteristic: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('캐릭터리스틱 쓰기 실패: $e')),
      );
    }
  }

  Future<void> _toggleNotify() async {
    try {
      await widget.characteristic.setNotifyValue(!widget.characteristic.isNotifying);
      if (mounted) {
        setState(() {}); // UI 업데이트
      }
      print("Notify for ${getCharacteristicName(widget.characteristic.uuid)} toggled to ${widget.characteristic.isNotifying}");
    } catch (e) {
      print("Error setting notify value: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알림 설정 실패: $e')),
      );
    }
  }

  Widget _buildButton(
      {required String text, required VoidCallback onPressed, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(text),\n      ),
    );
  }

  Widget _buildAcControlButtons() {
    if (widget.characteristic.uuid == AcBleUuids.POWER_STATE_CHARACTERISTIC_UUID) {
      return Row(
        children: [
          _buildButton(text: 'ON', onPressed: () => _writeValue([1])),
          _buildButton(text: 'OFF', onPressed: () => _writeValue([0])),
        ],
      );
    } else if (widget.characteristic.uuid == AcBleUuids.OPERATION_MODE_CHARACTERISTIC_UUID) {
      return Row(
        children: [
          _buildButton(text: 'COOL', onPressed: () => _writeValue([0])),
          _buildButton(text: 'HEAT', onPressed: () => _writeValue([1])),
          _buildButton(text: 'DRY', onPressed: () => _writeValue([2])),
        ],
      );
    } else if (widget.characteristic.uuid == AcBleUuids.TARGET_TEMPERATURE_CHARACTERISTIC_UUID) {
      return Row(
        children: [
          _buildButton(text: '+1°C', onPressed: () => _writeValue([(_value.isNotEmpty ? _value.first : 22) + 1])),
          _buildButton(text: '-1°C', onPressed: () => _writeValue([(_value.isNotEmpty ? _value.first : 22) - 1])),
        ],
      );
    } else if (widget.characteristic.uuid == AcBleUuids.FAN_SPEED_CHARACTERISTIC_UUID) {
      return Row(
        children: [
          _buildButton(text: 'AUTO', onPressed: () => _writeValue([0])),
          _buildButton(text: 'LOW', onPressed: () => _writeValue([1])),
          _buildButton(text: 'HIGH', onPressed: () => _writeValue([3])),
        ],
      );
    }
    return Container();
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
            Text('Characteristic: ${getCharacteristicName(widget.characteristic.uuid)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('UUID: ${widget.characteristic.uuid.str.toUpperCase()}'),
            Text('Current Value: ${_value.toString()}'),
            Text('Properties: R(${properties.read}) W(${properties.write}) N(${properties.notify}) I(${properties.indicate})'),
            Row(
              children: <Widget>[
                if (properties.read) _buildButton(text: 'READ', onPressed: _readValue),
                if (properties.write || properties.writeWithoutResponse)
                  // 에어컨 제어 캐릭터리스틱에 대한 특정 버튼 표시
                  if (_buildAcControlButtons() is! Container)
                    _buildAcControlButtons()
                  else
                    _buildButton(text: 'WRITE (Generic)', onPressed: () => _writeValue([1])),
                if (properties.notify || properties.indicate)
                  _buildButton(
                    text: widget.characteristic.isNotifying ? 'STOP NOTIFY' : 'START NOTIFY',
                    onPressed: _toggleNotify,
                  ),
              ],
            ),\n          ],
        ),
      ),
    );
  }
}
