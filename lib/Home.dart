import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController location = TextEditingController(text: 'Dhaka');

  bool Loading = false;
  String? errorMsg;

  //current
  double? temperature;
  double? windSpeed;
  int? wCode;
  String? wText;
  String? City;
  String? Country;

  List<Hourly> hourly = [];
  List<sevenDays> sevenD = [];

  Future<({String City, String Country, double Lat, double Long})> Geocoding(
    String location,
  ) async {
    Uri uri = Uri.parse(
      "https://geocoding-api.open-meteo.com/v1/search?name=$location&count=1&language=en&format=json",
    );
    Response response = await get(uri);
    Map<String, dynamic> data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      debugPrint(data.toString());
      String city = data["results"][0]['name'] ?? 'not found';
      City = city;
      String country = data["results"][0]['country_code'] ?? 'not found';
      Country = country;
      double lat = data["results"][0]['latitude'];
      double long = data["results"][0]['longitude'];
      print('$city $country $lat $long');
      return (City: city, Country: country, Lat: lat, Long: long);
    } else {
      debugPrint("something went wrong");
      return (City: '', Country: '', Lat: 0.0, Long: 0.0);
    }
  }

  GetData(String location, bool initial) async {
    if (!initial) Loading = true;
    setState(() {});
    final getGeo = await Geocoding(location);
    try {
      Uri uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=${getGeo.Lat}&longitude=${getGeo.Long}&daily=temperature_2m_max,'
        'temperature_2m_min,weather_code&hourly=temperature_2m,'
        'weather_code&current=temperature_2m,'
        'weather_code,wind_speed_10m',
      );
      Response response = await get(uri);
      Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        errorMsg = '';
        temperature = data["current"]['temperature_2m'];
        windSpeed = data["current"]['wind_speed_10m'];
        wCode = data["current"]["weather_code"];

        List times = data["hourly"]["time"] ?? [];
        List temp = data["hourly"]["temperature_2m"] ?? [];
        List weatherCode = data["hourly"]["weather_code"] ?? [];
        List<Hourly> list = [];

        List days = data['daily']['time'] ?? [];
        List maxTemp = data['daily']['temperature_2m_max'] ?? [];
        List minTemp = data['daily']['temperature_2m_min'] ?? [];

        for (int i = 0; i < times.length; i++) {
          list.add(
            Hourly(
              time: DateTime.parse(times[i]),
              temp: temp[i].toDouble(),
              code: weatherCode[i].toInt(),
            ),
          );
        }
        List<sevenDays> list1 = [];
        for (int i = 0; i < days.length; i++) {
          list1.add(
            sevenDays(
              Date: DateTime.parse(days[i]),
              max: maxTemp[i].toString(),
              min: minTemp[i].toString(),
            ),
          );
        }
        hourly = list;
        sevenD = list1;
      } else {
        errorMsg = "something went wrong";
      }
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      Loading = false;
      setState(() {});
    }
  }

  @override
  void initState() {
    GetData(location.text, true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Background(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(8),
            children: [
              FieldSection(),
              SizedBox(height: 16),
              InformationSection(),
              SizedBox(height: 16),
              Card(
                color:Colors.yellow.shade200,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "wind $windSpeed kmps",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: hourly.map((e) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text('${e.time.day}/${e.time.month}'),
                            Text('${e.time.hour}:${e.time.minute}'),
                            CodeToIcon(e.code),
                            Text('${e.temp}°'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Card(color: Colors.lightBlue.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: sevenD.map((e) {
                      return Container(
                        height:30,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${e.Date.year}-${e.Date.month}-${e.Date.day}'),
                            Text('High:${e.max}°'),
                            Text('Low:${e.min}°'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Column InformationSection() {
    return Column(
      children: [
        Text(
          City != num ? City.toString() : "Your Location",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        Text(
          Country != num ? Country.toString() : "Current Location",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          "$temperature°",
          style: TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        Text(
          CodeToText(wCode!),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  CodeToText(int c) {
    if (c == null) return '--';
    if (c == 0) return "Mostly Sunny";
    if ([1, 2, 3].contains(c)) {
      return 'partly cloud';
    }
    if ([45, 48].contains(c)) {
      return 'foggy';
    }
    return "cloud";
  }

  CodeToIcon(int c) {
    if (c == null) return '--';
    if (c == 0) return Icon(Icons.sunny);
    if ([1, 2, 3].contains(c)) {
      return Icon(Icons.sunny_snowing);
    }
    if ([45, 48].contains(c)) {
      return Icon(Icons.foggy);
    }
    return Icon(Icons.cloud);
  }

  Widget FieldSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: location,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              hintText: "Location",
              hintStyle: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
        SizedBox(width: 8),
        Visibility(
          visible: Loading == false,
          replacement: Center(child: CircularProgressIndicator()),
          child: FilledButton(
            onPressed: () {
              GetData(location.text, false);
            },
            child: Text("Search"),
          ),
        ),
      ],
    );
  }

  Widget Background({Widget? child}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white,
            Colors.lightBlueAccent,
            Colors.blueAccent,
            Colors.lightBlueAccent,
            Colors.blueAccent,
            Colors.blue,
          ],
        ),
      ),
      child: child,
    );
  }
}

class Hourly {
  final DateTime time;
  final double temp;
  final int code;

  Hourly({required this.time, required this.temp, required this.code});
}

class sevenDays {
  final DateTime Date;
  final String max;
  final String min;

  sevenDays({required this.Date, required this.max, required this.min});
}
