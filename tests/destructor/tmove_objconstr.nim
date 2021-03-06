
discard """
output:  '''test created
test destroyed 0
1
2
3
4
Pony is dying!'''
  cmd: '''nim c --newruntime $file'''
"""

# bug #4214
type
  Data = object
    data: string
    rc: int

proc `=destroy`(d: var Data) =
  dec d.rc
  echo d.data, " destroyed ", d.rc

proc `=`(dst: var Data, src: Data) =
  echo src.data, " copied"
  dst.data = src.data & " (copy)"
  dec dst.rc
  inc dst.rc

proc initData(s: string): Data =
  result = Data(data: s, rc: 1)
  echo s, " created"

proc pointlessWrapper(s: string): Data =
  result = initData(s)

proc main =
  var x = pointlessWrapper"test"

when isMainModule:
  main()

# bug #985

type
  Pony = object
    name: string

proc `=destroy`(o: var Pony) =
  echo "Pony is dying!"

proc getPony: Pony =
  result.name = "Sparkles"

iterator items(p: Pony): int =
  for i in 1..4:
    yield i

for x in getPony():
  echo x
# XXX this needs to be enabled once top level statements
# produce destructor calls again.
#echo "Pony is dying!"


#------------------------------------------------------------
#-- Move into tuple constructor and move on tuple unpacking
#------------------------------------------------------------

type
  MySeqNonCopyable* = object
    len: int 
    data: ptr UncheckedArray[float]

proc `=destroy`*(m: var MySeqNonCopyable) {.inline.} =
  if m.data != nil:
    deallocShared(m.data)
    m.data = nil

proc `=`*(m: var MySeqNonCopyable, m2: MySeqNonCopyable) {.error.}

proc `=sink`*(m: var MySeqNonCopyable, m2: MySeqNonCopyable) {.inline.} =
  if m.data != m2.data:
    if m.data != nil:
      `=destroy`(m)
    m.len = m2.len
    m.data = m2.data

proc len*(m: MySeqNonCopyable): int {.inline.} = m.len

proc `[]`*(m: MySeqNonCopyable; i: int): float {.inline.} =
  m.data[i.int]

proc `[]=`*(m: var MySeqNonCopyable; i, val: float) {.inline.} =
  m.data[i.int] = val

proc setTo(s: var MySeqNonCopyable, val: float) = 
  for i in 0..<s.len.int:
    s.data[i] = val

proc newMySeq*(size: int, initial_value = 0.0): MySeqNonCopyable =#
  result.len = size
  if size > 0:
    result.data = cast[ptr UncheckedArray[float]](createShared(float, size))

  result.setTo(initial_value)

proc myfunc(x, y: int): (MySeqNonCopyable, MySeqNonCopyable) =
  result = (newMySeq(x, 1.0), newMySeq(y, 5.0))

proc myfunc2(x, y: int): tuple[a: MySeqNonCopyable, b:int, c:MySeqNonCopyable] =
  (a: newMySeq(x, 1.0), b:0, c:newMySeq(y, 5.0))

let (seq1, seq2) = myfunc(2, 3)
doAssert seq1.len == 2
doAssert seq1[0] == 1.0
doAssert seq2.len == 3
doAssert seq2[0] == 5.0

var (seq3, i, _) = myfunc2(2, 3)
doAssert seq3.len == 2
doAssert seq3[0] == 1.0