class HjError {
  int code;
  String message;

  HjError(this.code, this.message);

  Map<String, dynamic> toJson() => {"code": code, "mesage": message};
}
