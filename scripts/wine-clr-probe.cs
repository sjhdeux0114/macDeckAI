using System;
class ClrProbe {
 static int Main() {
  Console.WriteLine("PASS native CLR " + Environment.Version + " ptr=" + IntPtr.Size);
  try { int z = int.Parse("0"); Console.WriteLine(1/z); return 2; }
  catch(DivideByZeroException) { Console.WriteLine("PASS CLR integer divide exception"); }
  Console.WriteLine("PASS CLR floating math " + Math.Sqrt(144.0));
  return 0;
 }
}
