import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppSpacing {
  // Widths
  static Widget get w4 => SizedBox(width: 4.w);
  static Widget get w6 => SizedBox(width: 6.w);
  static Widget get w8 => SizedBox(width: 8.w);
  static Widget get w10 => SizedBox(width: 10.w);
  static Widget get w12 => SizedBox(width: 12.w);
  static Widget get w14 => SizedBox(width: 14.w);
  static Widget get w15 => SizedBox(width: 15.w);
  static Widget get w16 => SizedBox(width: 16.w);
  static Widget get w18 => SizedBox(width: 18.w);
  static Widget get w20 => SizedBox(width: 20.w);
  static Widget get w24 => SizedBox(width: 24.w);
  static Widget get w32 => SizedBox(width: 32.w);

  // Heights
  static Widget get h2 => SizedBox(height: 2.h);
  static Widget get h4 => SizedBox(height: 4.h);
  static Widget get h5 => SizedBox(height: 5.h);
  static Widget get h6 => SizedBox(height: 6.h);
  static Widget get h8 => SizedBox(height: 8.h);
  static Widget get h10 => SizedBox(height: 10.h);
  static Widget get h12 => SizedBox(height: 12.h);
  static Widget get h14 => SizedBox(height: 14.h);
  static Widget get h15 => SizedBox(height: 15.h);
  static Widget get h16 => SizedBox(height: 16.h);
  static Widget get h18 => SizedBox(height: 18.h);
  static Widget get h20 => SizedBox(height: 20.h);
  static Widget get h22 => SizedBox(height: 22.h);
  static Widget get h24 => SizedBox(height: 24.h);
  static Widget get h25 => SizedBox(height: 25.h);
  static Widget get h28 => SizedBox(height: 28.h);
  static Widget get h30 => SizedBox(height: 30.h);
  static Widget get h32 => SizedBox(height: 32.h);
  static Widget get h40 => SizedBox(height: 40.h);
  static Widget get h50 => SizedBox(height: 50.h);
  static Widget get h60 => SizedBox(height: 60.h);
  static Widget get h70 => SizedBox(height: 70.h);
  static Widget get h80 => SizedBox(height: 80.h);
  static Widget get h90 => SizedBox(height: 90.h);
  static Widget get h100 => SizedBox(height: 100.h);
  static Widget get h120 => SizedBox(height: 120.h);
  static Widget get h250 => SizedBox(height: 250.h);

  // Shrink / Empty
  static const Widget empty = SizedBox.shrink();

  // Custom dynamic spacing helpers
  static Widget customH(double h) => SizedBox(height: h.h);
  static Widget customW(double w) => SizedBox(width: w.w);
}
