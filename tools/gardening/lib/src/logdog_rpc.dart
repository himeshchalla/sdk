// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'try.dart';
import 'cache_new.dart';

const String LOGDOG_HOST = "luci-logdog.appspot.com";

class LogdogRpc {
  Future<Try<String>> get(
      String project, String path, WithCacheFunction withCache) async {
    var uri = new Uri(
        scheme: "https", host: LOGDOG_HOST, path: "prpc/logdog.Logs/Get");
    var body = {"project": project, "path": path};
    var result = await tryStartAsync(() => withCache(
        () => _makePostRequest(uri, JSON.encode(body), {
              HttpHeaders.CONTENT_TYPE: "application/json",
              HttpHeaders.ACCEPT: "application/json"
            }),
        "logdog-get-$path"));
    return result.bind((str) => JSON.decode(str)).bind((json) {
      StringBuffer buffer = new StringBuffer();
      json["logs"].forEach((log) {
        buffer.write(log["text"]["lines"][0]["value"]);
      });
      return buffer.toString();
    });
  }

  Future<Try<List<LogdogStream>>> query(
      String project, String path, WithCacheFunction withCache) async {
    var uri = new Uri(
        scheme: "https", host: LOGDOG_HOST, path: "prpc/logdog.Logs/Query");
    var body = {"project": project, "path": path};
    var result = await tryStartAsync(() => withCache(
        () => _makePostRequest(uri, JSON.encode(body), {
              HttpHeaders.CONTENT_TYPE: "application/json",
              HttpHeaders.ACCEPT: "application/json"
            }),
        "logdog-query-$path"));
    return result.bind((str) => JSON.decode(str)).bind((json) {
      if (json["streams"] == null) {
        return <LogdogStream>[];
      }
      return json["streams"]
          .map((stream) => new LogdogStream(stream["path"]))
          .toList();
    });
  }

  /// [_makePostRequest] performs a post request to [uri], where the posted
  /// body is the string representation of [body]. For adding custom headers
  /// use the map [headers].
  Future<String> _makePostRequest(
      Uri uri, Object body, Map<String, String> headers) async {
    var response = await http.post(uri, body: body, headers: headers);
    if (response.statusCode != 200) {
      throw new HttpException(response.reasonPhrase, uri: uri);
    }
    // Prpc outputs a prefix to combat vulnerability.
    if (response.body.startsWith(")]}'")) {
      return response.body.substring(4);
    }
    return response.body;
  }
}

class LogdogStream {
  final String path;
  LogdogStream(this.path);
}
