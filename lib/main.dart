import 'dart:developer';

import 'package:calendar_spike/event_calendar_model.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/timezone.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var byteData = await rootBundle.load('assets/timezone/2022f.tzf');
  initializeDatabase(byteData.buffer.asUint8List());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  List<Calendar> _calendarsList = [];
  Calendar? _selectedCalendar;
  String _eventId = '96';

  /*Evento data: 286
  [log] Evento creado con exito: 901792640*/

  late final DeviceCalendarPlugin _deviceCalendarPlugin =
      DeviceCalendarPlugin();

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                  onPressed: () async {
                    var calendarios = await loadCalendars();
                    setState(() {
                      _calendarsList = calendarios;
                      _selectedCalendar = _calendarsList[2];
                    });
                  },
                  child: const Text("Listar calendarios")),
              ElevatedButton(
                  onPressed: () async {
                    if (_selectedCalendar == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text("Primero recupere la lista de calendarios"),
                      ));
                      return;
                    }
                    const newEvent = CalendarEventModel(
                      eventTitle: 'Test',
                      eventDescription: 'Spike prueba',
                      eventDurationInHours: 1,
                    );
                    await addToCalendar(newEvent, _selectedCalendar?.id ?? '');
                  },
                  child: const Text("Crear evento")),
              ElevatedButton(
                  onPressed: () async {
                    if (_selectedCalendar == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text("Primero recupere la lista de calendarios"),
                      ));
                      return;
                    }
                    const newEvent = CalendarEventModel(
                      eventTitle: 'Test',
                      eventDescription: 'Spike prueba',
                      eventDurationInHours: 1,
                    );
                    await editCalendarEvent(
                        newEvent, _selectedCalendar?.id ?? '', _eventId);
                  },
                  child: const Text("Editar evento")),
              ElevatedButton(
                  onPressed: () async {
                    if (_selectedCalendar == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text("Primero recupere la lista de calendarios"),
                      ));
                      return;
                    }
                    await deleteCalendarEvent(
                        _selectedCalendar?.id ?? '', _eventId);
                  },
                  child: const Text("Borrar evento")),
              const SizedBox(
                height: 16,
              ),
              const Text(
                "Lista de calendarios:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: 16,
              ),
              Column(
                children: getListCalendarItems(calendarList: _calendarsList),
              ),
              const SizedBox(
                height: 16,
              ),
              const Text(
                'Calendario selecionado:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('-> ${_selectedCalendar?.name ?? 'None'}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.blueAccent,
                  )),
            ],
          ),
        ) // This trailing comma makes auto-formatting nicer for build methods.
        );
  }

  List<Widget> getListCalendarItems({required List<Calendar> calendarList}) {
    List<Text> list = [];
    if (calendarList.isEmpty) {
      list.add(const Text('Vacio'));
      return list;
    }
    for (var element in calendarList) {
      list.add(Text(element.name ?? 'NoName'));
    }

    return list;
  }

  // Recupera la lista de calendarios del dispositivo
  Future<List<Calendar>> loadCalendars() async {
    // await Future.delayed(const Duration(seconds: 1));

    var _calendars;
    try {
      // Maneja la peticion de permisos
      var arePermissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (arePermissionsGranted.isSuccess &&
          !(arePermissionsGranted.data ?? false)) {
        arePermissionsGranted =
            await _deviceCalendarPlugin.requestPermissions();
        if (!arePermissionsGranted.isSuccess ||
            !(arePermissionsGranted.data ?? false)) {
          log('log - Sin permisos');
        }
      }
      // recupera los calendarios
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      _calendars = calendarsResult.data;
      if (_calendars.isEmpty || calendarsResult.errors.isNotEmpty) {
        log('log - error cargando calendarios');
      }
    } catch (e) {
      print(e.toString());
    }
    log('log - exito calendarios: $_calendars');
    return _calendars;
  }

  Future<void> addToCalendar(
      CalendarEventModel calendarEventModel, String selectedCalendarId) async {
    final eventTime = DateTime.now();
    final String currentTimeZone =
        await FlutterNativeTimezone.getLocalTimezone();

    var currentLocation = getLocation(currentTimeZone);
    setLocalLocation(currentLocation);
    log('Location: $currentLocation');

    var newTime = TZDateTime.from(eventTime, currentLocation);
    log('newTime: $newTime');

    log('newTime: $newTime');

    final eventToCreate = Event(
      selectedCalendarId,
      title: calendarEventModel.eventTitle,
      description: calendarEventModel.eventDescription,
      start: newTime,
      end:
          newTime.add(Duration(hours: calendarEventModel.eventDurationInHours)),
    );

    final createEventResult =
        await _deviceCalendarPlugin.createOrUpdateEvent(eventToCreate);

    if ((createEventResult?.isSuccess ?? false) &&
        (createEventResult?.data?.isNotEmpty ?? false)) {
      log('Evento creado con exito: $createEventResult');
      log('Evento data: ${createEventResult?.data}');
      log('Evento creado con exito: ${createEventResult?.hashCode}');
      log('Evento creado con exito: ${createEventResult?.errors}');
    } else {
      var errorMessage =
          'Could not create : ${createEventResult?.errors.toString()}';
      log('Error creando evento : $errorMessage');
    }
  }

  Future<void> editCalendarEvent(CalendarEventModel calendarEventModel,
      String selectedCalendarId, String eventID) async {
    final eventTime = DateTime.now();
    final String currentTimeZone =
        await FlutterNativeTimezone.getLocalTimezone();
    var currentLocation = getLocation(currentTimeZone);
    setLocalLocation(currentLocation);
    log('Location: $currentLocation');

    var newTime = TZDateTime.from(eventTime, currentLocation);
    log('newTime: $newTime');

    log('newTime: $newTime');

    final eventToCreate = Event(
      selectedCalendarId,
      eventId: _eventId,
      title: "${calendarEventModel.eventTitle} - Modificado",
      description: "${calendarEventModel.eventDescription} - Modificado",
      start: newTime.add(const Duration(hours: 1)),
      end: newTime
          .add(Duration(hours: calendarEventModel.eventDurationInHours + 1)),
    );

    final createEventResult =
        await _deviceCalendarPlugin.createOrUpdateEvent(eventToCreate);

    if ((createEventResult?.isSuccess ?? false) &&
        (createEventResult?.data?.isNotEmpty ?? false)) {
      log('Evento actualizado con exito: $createEventResult');
      log('Evento actualizado - data: ${createEventResult?.data}');
      log('Evento actualizado - hashcode: ${createEventResult?.hashCode}');
      log('Evento actualizado - errors: ${createEventResult?.errors}');
    } else {
      var errorMessage =
          'Could not update : ${createEventResult?.errors.toString()}';
      log('Error actualizando evento : $errorMessage');
    }
  }

  Future<void> deleteCalendarEvent(
      String selectedCalendarId, String eventID) async {
    // borr
    final createEventResult =
        await _deviceCalendarPlugin.deleteEvent(selectedCalendarId, eventID);

    if ((createEventResult.isSuccess ?? false) &&
        (createEventResult.data ?? false)) {
      log('Evento eliminado con exito: $createEventResult');
      log('Evento eliminado - data: ${createEventResult.data}');
      log('Evento eliminado - hashcode: ${createEventResult.hashCode}');
      log('Evento ekiminado - errors: ${createEventResult.errors}');
    } else {
      var errorMessage =
          'Could not delete : ${createEventResult?.errors.toString()}';
      log('Error eliminando evento : $errorMessage');
    }
  }
}
