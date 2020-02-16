import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_auth0/flutter_auth0.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:x_qrcode/events/events_screen.dart';
import 'package:x_qrcode/organization/user.dart';

import '../constants.dart';
import 'company.dart';

const organisationsRoute = '/organizations';

class OrganizationsScreen extends StatefulWidget {
  OrganizationsScreen({Key key}) : super(key: key);

  @override
  _OrganizationsScreenState createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final Auth0 auth0 = Auth0(
      baseUrl: DotEnv().env[ENV_KEY_OAUTH_AUTH_URL],
      clientId: DotEnv().env[ENV_KEY_OAUTH_CLIENT_ID]);
  final FlutterSecureStorage storage = FlutterSecureStorage();

  Future<UserInfo> userInfo;

  @override
  void initState() {
    _pushEventsIfOrganisationExists();
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Color.fromARGB(255, 45, 56, 75),
        body: Padding(
          padding: EdgeInsets.all(48),
          child: FutureBuilder<UserInfo>(
            future: userInfo,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Column(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(top: 64, bottom: 16),
                      child: RichText(
                        text: TextSpan(
                            text: '',
                            style: TextStyle(color: Colors.white),
                            children: [
                              TextSpan(
                                  text: 'Bonjour ${snapshot.data.firstName}',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(
                                text:
                                    ', sélectionnez une organisation pour continuer.',
                              ),
                            ]),
                      ),
                    ),
                    ListBody(
                        children: snapshot.data.tenants
                            .map((tenant) => RaisedButton(
                                  onPressed: () async {
                                    var company = await _getCompany(tenant);
                                    var user = User(
                                        snapshot.data.firstName,
                                        snapshot.data.lastName,
                                        tenant,
                                        company);
                                    await FlutterSecureStorage().write(
                                        key: STORAGE_KEY_USER,
                                        value: jsonEncode(user));
                                    Navigator.pushNamed(context, eventsRoute);
                                  },
                                  child: Text(tenant),
                                ))
                            .toList()),
                  ],
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      );

  Future<UserInfo> _getUserInfo() async {
    final accessToken =
        await FlutterSecureStorage().read(key: STORAGE_KEY_ACCESS_TOKEN);
    final auth0Auth = Auth0Auth(auth0.auth.clientId, auth0.auth.client.baseUrl,
        bearer: accessToken);
    final info = await auth0Auth.getUserInfo();
    return UserInfo.fromJson(info);
  }

  Future<Company> _getCompany(tenant) async {
    final accessToken =
        await FlutterSecureStorage().read(key: STORAGE_KEY_ACCESS_TOKEN);
    final response = await http.get(
        '${DotEnv().env[ENV_KEY_API_URL]}/$tenant/companies/my-company',
        headers: {HttpHeaders.authorizationHeader: "Bearer $accessToken"});
    if (response.statusCode == 200) {
      return Company.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Cannot get company');
    }
  }

  void _pushEventsIfOrganisationExists() {
    Future(() {
      storage.read(key: STORAGE_KEY_USER).then((user) {
        if (user != null) {
          Navigator.pushNamed(context, eventsRoute);
        } else {
          userInfo = _getUserInfo();
        }
      });
    });
  }
}

class UserInfo {
  final String firstName;
  final String lastName;
  final List<String> tenants;

  UserInfo(this.firstName, this.lastName, this.tenants);

  UserInfo.fromJson(Map<dynamic, dynamic> json)
      : firstName = json['$APP_NAMESPACE/claims/user_metadata']['firstName'],
        lastName = json['$APP_NAMESPACE/claims/user_metadata']['lastName'],
        tenants = List<String>.from(
            json['$APP_NAMESPACE/claims/app_metadata']['tenants']);
}
