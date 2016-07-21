// -----------------------------------------------------------------------------
// math.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/math.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Constants

const double M_E = 2.71828182845904523536;
const double M_LOG2E = 1.44269504088896340736;
const double M_LOG10E = 0.434294481903251827651;
const double M_LN2 = 0.693147180559945309417;
const double M_LN10 = 2.30258509299404568402;
const double M_PI = 3.14159265358979323846;
const double M_PI_2 = 1.57079632679489661923;
const double M_PI_4 = 0.785398163397448309616;
const double M_1_PI = 0.318309886183790671538;
const double M_2_PI = 0.636619772367581343076;
const double M_2_SQRTPI = 1.12837916709551257390;
const double M_SQRT2 = 1.41421356237309504880;
const double M_SQRT1_2 = 0.707106781186547524401;

// ---------------------------------------------------------

// Misc functions

double      fabs(double x)
double      fdim(double x, double y)
double      fma(double x, double y, double z)
double      ldexp(double x, int exp)

// Root functions

double      cbrt(double x)
double      sqrt(double x)

// Exponential and logarithmic functions

double      exp(double x)
double      exp2(double x)
double      expm1(double x)
double      log(double x)
double      log2(double x)
double      log10(double x)
double      pow(double base, double exponent)

// Trigonometric functions

double      acos(double x)
double      asin(double x)
double      atan(double x)
double      cos(double x)
double      hypot(double x, double y)
double      sin(double x)
double      tan(double x)

// Hyperbolic functions

double      acosh(double x)
double      asinh(double x)
double      atanh(double x)
double      cosh(double x)
double      sinh(double x)
double      tanh(double x)

// Range

double      fmax(double x, double y)
double      fmin(double x, double y)

// Rounding, factions, decomposition

double      ceil(double x)
double      floor(double x)
double      fmod(double numer, double denom)
double      remainder(double numer, double denom)
double      round(double x)
double      trunc(double x)

// Special functions

double      erf(double x)
double      erfc(double x)
double      lgamma(double x)
double      tgamma(double x)
