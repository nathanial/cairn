/-
  Cairn/Input/Keys.lean - Platform-specific key codes
-/

namespace Cairn.Input

-- macOS virtual key codes
namespace Keys

def w : UInt16 := 13
def a : UInt16 := 0
def s : UInt16 := 1
def d : UInt16 := 2
def q : UInt16 := 12
def e : UInt16 := 14
def escape : UInt16 := 53
def space : UInt16 := 49
def leftShift : UInt16 := 56
def leftControl : UInt16 := 59

-- Number keys (for hotbar selection)
def key1 : UInt16 := 18
def key2 : UInt16 := 19
def key3 : UInt16 := 20
def key4 : UInt16 := 21
def key5 : UInt16 := 23
def key6 : UInt16 := 22
def key7 : UInt16 := 26
def key8 : UInt16 := 28
def key9 : UInt16 := 25

/-- Get key code for hotbar index (0-based) -/
def hotbarKey (index : Nat) : UInt16 :=
  match index with
  | 0 => key1
  | 1 => key2
  | 2 => key3
  | 3 => key4
  | 4 => key5
  | 5 => key6
  | 6 => key7
  | _ => 0  -- Invalid

end Keys

end Cairn.Input
