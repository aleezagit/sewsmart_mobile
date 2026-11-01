// Input checks shared by the app's forms. The backend checks the same values
// again; these give the user a quick message before anything is sent.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  // A Pakistani mobile number: 0300-1234567, 03001234567 or +92 300 1234567.
  static bool isMobile(String value) {
    final digits = digitsOnly(value);
    return (digits.length == 11 && digits.startsWith('03')) ||
        (digits.length == 12 && digits.startsWith('923'));
  }

  // A mobile number as the backend stores it: 03001234567.
  static String normalizeMobile(String value) {
    final digits = digitsOnly(value);
    return digits.length == 12 && digits.startsWith('92') ? '0${digits.substring(2)}' : digits;
  }

  // A CNIC number: 13 digits, with or without dashes (35202-1234567-1).
  static bool isCnic(String value) => digitsOnly(value).length == 13;

  // A Pakistani IBAN: PK, two check digits, a 4-letter bank code and 16 digits.
  static bool isIban(String value) =>
      RegExp(r'^PK\d{2}[A-Z]{4}\d{16}$').hasMatch(value.replaceAll(' ', '').toUpperCase());

  // What to fix in a payout account form, or null when it is complete.
  static String? payoutAccountProblem({
    required bool isBank,
    required String number,
    required String holderName,
    String bankName = '',
    String iban = '',
  }) {
    if (isBank) {
      if (bankName.trim().isEmpty) return 'Choose your bank';
      if (digitsOnly(number).length < 8) return 'Enter the full account number';
      if (iban.trim().isNotEmpty && !isIban(iban)) {
        return 'Enter a valid IBAN, e.g. PK36HABB0000123456789012';
      }
    } else if (!isMobile(number)) {
      return 'Enter the wallet mobile number, e.g. 0300-1234567';
    }
    if (holderName.trim().isEmpty) return 'Enter the account holder name';
    return null;
  }

  // A number greater than zero, or null when the text is not one.
  static double? positiveNumber(String value) {
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) return null;
    return number;
  }
}
