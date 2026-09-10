{ ... }:
{
  assertions = [
    {
      assertion = true;
      message = "this assertion never fires";
    }
  ];

  locals.yolo = "value";
}
