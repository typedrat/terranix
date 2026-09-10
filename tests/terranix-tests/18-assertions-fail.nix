{ ... }:
{
  assertions = [
    {
      assertion = false;
      message = "first problem";
    }
    {
      assertion = true;
      message = "not a problem";
    }
    {
      assertion = false;
      message = "second problem";
    }
  ];
}
