import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tipografía oficial del ecosistema Apple (SF Pro & SF Mono)
abstract final class AppTypography {
  // Letras cantadas en el Teleprompter (SF Pro Bold / Heavy)
  static TextStyle sfProLyricStyle({double fontSize = 28, Color color = AppColors.textWhite}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color,
    );
  }

  // Notas musicales y acordes (SF Mono para alineación milimétrica)
  static TextStyle sfMonoChordStyle({double fontSize = 16, Color color = AppColors.chordAmber}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: color,
    );
  }

  // Títulos de interfaz estilo iOS
  static TextStyle sfProHeadline({double fontSize = 20, Color color = AppColors.textWhite}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  // Texto de cuerpo estilo iOS
  static TextStyle sfProBody({double fontSize = 15, Color color = AppColors.textWhite}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  // Subtítulos y tooltips
  static TextStyle sfProCaption({double fontSize = 13, Color color = AppColors.textSecondary}) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }
}
