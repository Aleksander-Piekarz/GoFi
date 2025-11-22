import 'dart:math';

class UnitConverter {
  final String unitSystem; 

  UnitConverter({required this.unitSystem});

  static const double kgToLbs = 2.20462;
  static const double lbsToKg = 0.453592;

  
  String get unitLabel => unitSystem == 'metric' ? 'kg' : 'lbs';

  
  double displayWeight(double kg) {
    if (unitSystem == 'metric') {
      return _round(kg); 
    } else {
      return _round(kg * kgToLbs); 
    }
  }

  
  double saveWeight(double displayValue) {
    if (unitSystem == 'metric') {
      return displayValue; 
    } else {
      return displayValue * lbsToKg; 
    }
  }

  
  double _round(double val) {
    return (val * 10).round() / 10;
  }
}