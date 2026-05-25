abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message); // "لا يوجد اتصال بالإنترنت"
}

class LocationFailure extends Failure {
  const LocationFailure(super.message); // "إذن الموقع مرفوض"
}