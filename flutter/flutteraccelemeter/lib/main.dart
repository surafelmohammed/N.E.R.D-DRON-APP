import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter_3d_obj/flutter_3d_obj.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensors Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<BluetoothDevice> _devices = [];
  List<BluetoothDiscoveryResult> results = List<BluetoothDiscoveryResult>();
  BluetoothConnection connection;
  String trial_string;

  List<DropdownMenuItem<String>> _data = [];

  List<double> _accelerometerValues;
  List<double> _userAccelerometerValues;
  List<double> _gyroscopeValues;
  final List<double> updatedAccValues = [];
  List<StreamSubscription<dynamic>> _streamSubscriptions =
      <StreamSubscription<dynamic>>[];
  List<String> addresses = [];
  String connectionAdress = '';
  List<int> dataList = [1, 3, 4, 5];
  bool ifconnected = false;
  @override
  Widget build(BuildContext context) {
    final List<String> accelerometer =
        _accelerometerValues?.map((double v) => v.toStringAsFixed(1))?.toList();
    final List<String> gyroscope =
        _gyroscopeValues?.map((double v) => v.toStringAsFixed(1))?.toList();
    final List<String> userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        ?.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Example'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Transform(
            transform: Matrix4(
              1,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              1,
            )
              ..rotateX(_accelerometerValues[0])
              ..rotateY(_accelerometerValues[1])
              ..rotateZ(_accelerometerValues[2]),
            alignment: FractionalOffset.center,
            child: Center(
              child: Object3D(
                size: Size(400.0, 400.0),
                path: "assets/Crate1.obj",
                asset: true,
              ),
            ),
          ),
          Padding(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Accelerometer: $accelerometer'),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          ),
          Padding(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('UserAccelerometer: $userAccelerometer'),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          ),
          Padding(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Gyroscope: $gyroscope'),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          ),
          Center(
            child: FloatingActionButton(
              child: Text('refresh'),
              onPressed: refresh,
            ),
          ),
          Padding(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                RaisedButton(
                  child: Icon(Icons.accessibility),
                  onPressed: () => connect(),
                ),
                DropdownButton(
                  icon: Icon(Icons.arrow_downward),
                  value: connectionAdress,
                  iconSize: 14,
                  elevation: 16,
                  items: _data,
                  onChanged: (String newAddress) {
                    setState(() {
                      connectionAdress = newAddress;
                    });
                  },
                ),
                RaisedButton(
                  child: Text('send data'),
                  onPressed: () {
                    send(Uint8List(2));
                  },
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          ),
        ],
      ),
    );
  }

  void initDiscovery(List<BluetoothDiscoveryResult> results) {
    _data = [];
    List<String> newAddresses = [];
    if (FlutterBluetoothSerial.instance.isDiscovering != null) {
      print('trying to discover');
    }
    StreamSubscription<BluetoothDiscoveryResult> streamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      results.add(r);
    });
    streamSubscription.onDone(() {
      //Do something when the discovery process ends
      streamSubscription.cancel();
      if (results.isEmpty) {
        print('what the fuck');
      } else {
        results.forEach((result) {
          newAddresses.add(result.device.address);
        });
        addresses = newAddresses.toSet().toList();
        setState(() {
          addresses.forEach((address) {
            if (connectionAdress.isEmpty) {
              connectionAdress = address;
            }
            _data.add(new DropdownMenuItem(
              child: new Text(address),
              value: address,
            ));
          });
        });
      }
    });
  }

  Future<void> connect() async {
    disconnect();
    try {
      BluetoothConnection.toAddress(connectionAdress).then((_connection) async {
        setState(() {
          connection = _connection;
        });
        print('connected one is established ' '$connection');
        // connection.input.listen((Uint8List data) {
        //   //Data entry point
        //   print(ascii.decode(data));
        // });
      });
    } catch (exception) {
      //print(exception);
      print('Cannot connect, exception occured');
    }
  }

  void disconnect() {
    if (connection != null) {
      if (connection.isConnected) {
        connection.close();
        connection = null;
      }
    }
  }

  Future send(Uint8List dataSent) async {
    try {
      connection.output.add(ascii.encode('source'));
      await connection.output.allSent;
    } catch (e) {
      print('could not send the data');
      print(e);
    }
  }

  void refresh() {
    initDiscovery(results);
  }

  @override
  void dispose() {
    super.dispose();
    for (StreamSubscription<dynamic> subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _streamSubscriptions
        .add(accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions.add(gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues = <double>[event.x, event.y, event.z];
      });
    }));
    _streamSubscriptions
        .add(userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      setState(() {
        _userAccelerometerValues = <double>[event.x, event.y, event.z];
      });
    }));
    initDiscovery(results);
  }
}
