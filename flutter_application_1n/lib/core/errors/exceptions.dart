class ServerException implements Exception {
  final String? message;
  ServerException({this.message});
}

class CacheException implements Exception {}

class NetworkException implements Exception {}

class UnauthenticatedException implements Exception {}