// Design Ref: §3.1 — UserModel with snake_case→camelCase JSON mapping
class UserModel {
  final int seq;
  final String userUUID;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userCell;
  final String? userProfileURL;
  final String companyKey;
  final int userType;
  final int userLevel;
  final String? userAddress;
  final String? userAddressDetail;
  final String? userBankAccount;
  final String? userBankHolder;
  final String? userBankName;
  final String? memo;
  final String? createDT;
  final String? updateDT;

  UserModel({
    required this.seq,
    required this.userUUID,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userCell,
    this.userProfileURL,
    required this.companyKey,
    required this.userType,
    required this.userLevel,
    this.userAddress,
    this.userAddressDetail,
    this.userBankAccount,
    this.userBankHolder,
    this.userBankName,
    this.memo,
    this.createDT,
    this.updateDT,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      seq: json['seq'] as int,
      userUUID: json['user_UUID'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userEmail: json['user_email'] as String?,
      userCell: json['user_cell'] as String?,
      userProfileURL: json['user_profileURL'] as String?,
      companyKey: json['company_key'].toString(),
      userType: json['user_type'] as int,
      userLevel: json['user_level'] as int,
      userAddress: json['user_address'] as String?,
      userAddressDetail: json['user_address_detail'] as String?,
      userBankAccount: json['user_bank_account'] as String?,
      userBankHolder: json['user_bank_holder'] as String?,
      userBankName: json['user_bank_name'] as String?,
      memo: json['memo'] as String?,
      createDT: json['create_DT'] as String?,
      updateDT: json['update_DT'] as String?,
    );
  }

  String get userTypeName {
    switch (userType) {
      case 9: return '관리자';
      case 8: return '회사사용자';
      case 7: return '직원';
      case 6: return '퇴직관리';
      default: return '알 수 없음';
    }
  }

  String get userLevelName {
    switch (userLevel) {
      case 9: return '마스터';
      case 8: return '회사마스터';
      case 7: return '회사직원';
      default: return '알 수 없음';
    }
  }
}
