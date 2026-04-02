/******************************************************************************
 *
 * Name:     csharp_strings.i
 * Project:  GDAL CSharp Interface
 * Purpose:  Typemaps for C# marshalling to/from UTF-8.
 * Authors:  Tamas Szekeres, szekerest@gmail.com
 *           Michael Bucari-Tovo, mbucari1@gmail.com
 *
 ******************************************************************************
 * Copyright (c) 2007, Tamas Szekeres; 2026, Michael Bucari-Tovo
 *
 * SPDX-License-Identifier: MIT
 *****************************************************************************/


%insert(runtime) %{
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
%}


/******************************************************************************
 * Marshaler for NULL terminated UTF-8 encoded strings                        *
 ******************************************************************************/

%insert(runtime) %{
/* Callback for returning strings to C# without leaking memory */
typedef char * (SWIGSTDCALL* CSharpUtf8StringHelperCallback)(const char *);
static CSharpUtf8StringHelperCallback SWIG_csharp_string_callback = NULL;
%}

%pragma(csharp) imclasscode=%{
  public class Utf8StringHelper {

    public delegate System.IntPtr Utf8StringDelegate(System.IntPtr message);

    static Utf8StringDelegate stringDelegate = new Utf8StringDelegate($modulePINVOKE.Utf8UnmanagedToLengthPrefixedUtf16Unmanaged);

    [global::System.Runtime.InteropServices.DllImport("$dllimport", EntryPoint="RegisterUtf8StringCallback_$module")]
    public static extern void RegisterUtf8StringCallback_$module(Utf8StringDelegate stringDelegate);

    static Utf8StringHelper() {
      RegisterUtf8StringCallback_$module(stringDelegate);
    }
  }
  
  public static readonly Utf8StringHelper utf8StringHelper = new Utf8StringHelper();
  
  public unsafe static IntPtr Utf8UnmanagedToLengthPrefixedUtf16Unmanaged(IntPtr pUtf8Bts)
  {
    if (pUtf8Bts == IntPtr.Zero)
      return IntPtr.Zero;

    byte* pStringUtf8 = (byte*)pUtf8Bts;
    int len = 0;
    while (pStringUtf8[len] != 0) len++;

    var charCount = System.Text.Encoding.UTF8.GetCharCount(pStringUtf8, len);
    var bstrDest = Marshal.AllocHGlobal(sizeof(int) + charCount * sizeof(char));
    *(int*)bstrDest = charCount;

    System.Text.Encoding.UTF8.GetChars(pStringUtf8, len, (char*)IntPtr.Add(bstrDest, sizeof(int)), charCount);
    return bstrDest;
  }

  public unsafe static string LengthPrefixedUtf16UnmanagedToString(IntPtr pBstr)
  {
    if (pBstr == IntPtr.Zero)
      return null;

    try
    {
      int charCount = *(int*)pBstr;
      if (charCount < 0)
        return null;
      int charStart = sizeof(int) / sizeof(char);
      return new string((char*)pBstr, charStart, charCount);
    }
    finally
    {
      Marshal.FreeHGlobal(pBstr);
    }
  }

  public unsafe static IntPtr StringToUtf8Unmanaged(string str)
  {
    if (str == null)
      return IntPtr.Zero;

    int byteCount = System.Text.Encoding.UTF8.GetByteCount(str);
    IntPtr unmanagedString = Marshal.AllocHGlobal(byteCount + 1);

    byte* ptr = (byte*)unmanagedString.ToPointer();
    fixed (char *pStr = str)
    {
      System.Text.Encoding.UTF8.GetBytes(pStr, str.Length, ptr, byteCount);
      // null-terminate
      ptr[byteCount] = 0;
    }

    return unmanagedString;
  }
  
  public static byte[] StringToUtf8Bytes(string str)
  {
    if (str == null)
      return null;

    int bytecount = System.Text.Encoding.UTF8.GetByteCount(str);
    byte[] bytes = new byte[bytecount + 1];
    System.Text.Encoding.UTF8.GetBytes(str, 0, str.Length, bytes, 0);
    return bytes;
  }
%}

%insert(runtime) %{
#ifdef __cplusplus
extern "C" 
#endif
SWIGEXPORT void SWIGSTDCALL RegisterUtf8StringCallback_$module(CSharpUtf8StringHelperCallback callback) {
  SWIG_csharp_string_callback = callback;
}
%}

/******************************************************************************
 * Apply typemaps for all SWIG string types and for const char *utf8_string   *
 ******************************************************************************/

/* Changing csin and imtype typemaps for string types defined by SWIG in csharp.swg */

%typemap(imtype, out="IntPtr") (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string) "byte[]"

%typemap(in) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string) %{
  $1 = ($1_ltype)$input;
%}

%typemap(out) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string)
%{
  $result = SWIG_csharp_string_callback((const char *)$1);
%}

%typemap(csin) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string) "$modulePINVOKE.StringToUtf8Bytes($csinput)"

%typemap(csout, excode=SWIGEXCODE) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string)
  {
    /* %typemap(csout) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string) */
    IntPtr cPtr = $imcall;
    string ret = $modulePINVOKE.LengthPrefixedUtf16UnmanagedToString(cPtr);
    $excode
    return ret;
  }

%typemap(csvarout, excode=SWIGEXCODE2) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string) %{
  get {
    /* %typemap(csvarout) (char *), (char *&), (char[ANY]), (char[]), (const char *utf8_string) */
    IntPtr cPtr = $imcall;
    string ret = $modulePINVOKE.LengthPrefixedUtf16UnmanagedToString(cPtr);
    $excode
    return ret;
  } %}
