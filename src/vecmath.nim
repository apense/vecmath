## The MIT License (MIT)
## 
## Copyright (c) 2014 Charlie Barto
## 
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
## 
## The above copyright notice and this permission notice shall be included in all
## copies or substantial portions of the Software.
## 
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.
import math
import strutils
import unsigned
import private/intrinsic

type ColMajor = object
type RowMajor = object
type Options = generic x
  x is ColMajor or
    x is RowMajor

type 
  TMatrix*[N: static[int]; M: static[int]; T; O: Options] = object
    data*: array[0..M*N-1, T]

type 
  SquareMatrix[N: static[int], T] = TMatrix[N,N,T,ColMajor]

type
  TVec*[N: static[int]; T] = TMatrix[N, 1, T, ColMajor]
  TVec3*[T] = TVec[3, T]
  TVec4*[T] = TVec[4, T]
  TVecf*[N: static[int]] = TMatrix[N, 1, float32, ColMajor]
  TMat2*[T] = TMatrix[2,2,T, ColMajor]
  TMat3*[T] = TMatrix[3,3,T, ColMajor]
  TMat4*[T] = TMatrix[4,4,T, ColMajor]
  TMat4f* = TMatrix[4, 4, float32, ColMajor]
  TMat3f* = TMatrix[3, 3, float32, ColMajor]
  TMat2f* = TMatrix[2, 2, float32, ColMajor]
  TVec6f* = TMatrix[6, 1, float32, ColMajor]
  TVec5f* = TMatrix[5, 1, float32, ColMajor]
  TVec4f* = TMatrix[4, 1, float32, ColMajor]
  TVec3f* = TMatrix[3, 1, float32, ColMajor]
  TVec2f* = TMatrix[2, 1, float32, ColMajor]
  TMatf*[N, M: static[int]] = TMatrix[N, M, float32, ColMajor]
  TQuatf* = distinct array[1..4, float32] #poor man's quaternion

type
  TAlignedBox3f* = object
    min*: TVec3f
    max*: TVec3f

type TCornerType* = enum
  ctBottomLeftFloor = 0
  ctBottomRightFloor = 1
  ctTopLeftFloor = 2
  ctTopRightFloor = 3
  ctBottomLeftCeil = 4
  ctBottomRightCeil = 5
  ctTopLeftCeil = 6
  ctTopRightCeil = 7

type TAxis* = enum
  axisYZ = 1
  axisXZ = 2
  axisXY = 3

type TRay* = object
  dir*: TVec3f
  origin*: TVec3f

proc `[]=`*(self: var TMatrix; i,j: int; val: TMatrix.T) =
  when self.O is RowMajor:
    var idx = (self.M * (i-1)) + (j-1)
    self.data[idx] = val
  when self.O is ColMajor:
    var idx = (self.N * (j-1)) + (i-1)
    self.data[idx] = val

proc `[]`*(self: TMatrix; i,j: int): TMatrix.T =
  when self.O is RowMajor:
    var idx = (self.M * (i-1)) + (j-1)
    result = self.data[idx]
  when self.O is ColMajor:
    var idx = (self.N * (j-1)) + (i-1)
    result = self.data[idx]

proc `[]`*(self: TVec; i: int): TVec.T =
  result = self[i, 1]

proc `[]=`*(self: var TVec; i: int; val: TVec.T) =
  self[i, 1] = val

proc vec2f*(x,y: float32): TVec2f =
  result.data = [x,y]

proc vec3f*(x,y,z: float32): TVec3f =
  result.data = [x,y,z]

proc vec3f*(vec: TVec4f): TVec3f =
  result[1] = vec[1]
  result[2] = vec[2]
  result[3] = vec[3]

proc vec4f*(x,y,z,w: float32): TVec4f =
  result.data = [x,y,z,w]

proc vec4f*(v: TVec3f, w: float32): TVec4f =
  result.data = [v[1], v[2], v[3], w]

proc vec4*[T](x,y,z,w: T): TVec4[T] =
  result.data = [x,y,z,w]

proc vec4*[T](v: TVec3[T], w: T): TVec4[T] =
  result.data = [v[1], v[2], v[3], w]


proc rows*(mtx: TMatrix): int = mtx.N
proc cols*(mtx: TMatrix): int = mtx.M

proc len*(a: TVec): int =
  result = a.data.len

proc dot*(a, b: TVec): TVec.T =
  #FIXME: perhaps this should return a float
  assert(a.len == b.len)
  for i in 1..a.N:
    result += a[i] * b[i]

proc length*(a: TVec): float =
  result = sqrt(dot(a,a).float)

proc row*(a: TMatrix; i: int): auto =
  result = TVec[a.M, a.T]()
  for idx in 1..a.M:
    result[idx] = a[i,idx]

proc col*(a: TMatrix; j: int): auto =
  result = TVec[a.N, a.T]()
  for idx in 1..a.N:
    result[idx] = a[idx, j]

proc `/`*(a: TMatrix, c: float): TMatrix =
  for i in 1..a.N:
    for j in 1..a.M:
      result[i,j] = a[i,j] / c

proc sub*(self: TMatrix; r,c: int): auto =
  ## returns a submatrix of `self`, that is
  ## we delete the ith row and jth column
  ## and return the resulting matrix
  result = TMatrix[self.N - 1, self.M - 1, self.T, self.O]()
  for i in 1..self.N-1:
    for j in 1..self.M-1:
      # we just handle the four cases here
      # we could be in any one of the four quadrents
      # defined by the row and col we are removing
      if i >= r and j >= c: result[i,j] = self[i+1,j+1]
      elif i >= r: result[i,j] = self[i+1, j]
      elif j >= c: result[i,j] = self[i, j+1]
      else: result[i,j] = self[i,j]

proc transpose*(a: TMatrix): TMatrix =
  for i in 1..a.N:
    for j in 1..a.M:
      result[i,j] = a[j,i]

proc det*(a: SquareMatrix): float =
  when a.N == 2:
    result = (a[1,1] * a[2,2]) - (a[1,2] * a[2,1])
  else:
    for i in 1..a.N:
      var sgn = pow((-1).float,(i + 1).float)
      result += sgn * a[i,1] * det(a.sub(i,1))

discard """
proc det2*(a: TMat2f): float =
  result = (a[1,1] * a[2,2]) - (a[1,2] * a[2,1])
proc det*(a: TMat3f): float =
  for i in 1..3:
    var sgn = pow((-1).float, (i + 1).float)
    result += sgn * a[i,1] * det2(a.sub(i,1))
"""

proc adj2*(a: TMat2f): TMat2f =
  result[1,1] = a[2,2]
  result[1,2] = -a[1,2]
  result[2,1] = -a[2,1]
  result[2,2] = a[1,1]

proc adj3*(a: TMat3f): TMat3f =
  result[1,1] = +(a[2,2]*a[3,3]-a[2,3]*a[3,2])
  result[1,2] = -(a[1,2]*a[3,3]-a[1,3]*a[3,2])
  result[1,3] = +(a[1,2]*a[2,3]-a[1,3]*a[2,2])
  result[2,1] = -(a[2,1]*a[3,3]-a[2,3]*a[3,1])
  result[2,2] = +(a[1,1]*a[3,3]-a[1,3]*a[3,1])
  result[2,3] = -(a[1,1]*a[2,3]-a[1,3]*a[2,1])
  result[3,1] = +(a[2,1]*a[3,2]-a[2,2]*a[3,1])
  result[3,2] = -(a[1,1]*a[3,2]-a[1,2]*a[3,1])
  result[3,3] = +(a[1,1]*a[2,2]-a[1,2]*a[2,1])

proc adj*(a: TMat4f): TMat4f =
  for i in 1..4:
    for j in 1..4:
      var sgn = pow((-1).float, (i+j).float)
      result[i,j] = sgn * det(a.sub(j,i))

proc inverse*(a: TMat4f): TMat4f =
  result = adj(a)/det(a)

proc trace*(a: SquareMatrix): float =
  for i in 1..a.N:
    result += float(a[i,i])

proc initMat3f*(arrs: array[0..8, float32]): TMat3f = 
  result.data = arrs
  result = transpose(result)

proc initMat2f*(arrs: array[0..3, float32]): TMat2f =
  result.data = arrs
  result = transpose(result)

proc mat3f*(mat: TMat4f): TMat3f =
  for i in 1..3:
    for j in 1..3:
      result[i,j] = mat[i,j]

proc `$`*(a: TMatrix): string =
  ## Hopefully, this'll make [[1,2,3],[4,5,6]]
  ## print out as
  ## 
  ## [ 1 2 3 ]
  ## [ 4 5 6 ]
  ##
  result = "\n"
  for i in 1..a.N:
    result &= "[ "
    for j in 1..a.M:
      result &= $a[i,j] & " "
    result &= "]\n"

proc mul*(a: TMat4f; b: TMat4f): TMat4f =
  for i in 1..4:
    for j in 1..4:
      result[i,j] = dot(row(a,i), col(b,j))

proc mulv*(a: TMat3f, b: TVec3f): TVec3f =
  for i in 1..3:
    result[i] = dot(a.row(i), b)

proc mul4v*(a: TMat4f, v: TVec4f): TVec4f =
  for i in 1..4:
    result[i] = dot(a.row(i), v)

proc mul3v*(a: TMat4f, b: TVec3f): TVec3f =
  result = vec3f(mul4v(a, vec4f(b, 1)))

proc mul3vd*(a: TMat4f, b: TVec3f): TVec3f =
  ## treats the input as a direction, not as a position
  result = vec3f(mul4v(a, vec4f(b, 0)))

discard """
proc mul*(a: TMat3f; b: TMat3f): TMat3f =
  for i in 1..3:
    for j in 1..3:
      result[i,j] = dot(row(a,i), col(b,j))
"""
#proc `==`*(a: TMatrix; b: TMatrix): bool =
#  result = a.data == b.data

proc identity4f*(): TMat4f =
  for i in 1..4:
    result[i,i] = 1'f32

proc identity3f*(): TMat3f =
  for i in 1..3:
    result[i,i] = 1'f32

proc identity4*[T](): TMat4[T] =
  for i in 1..4:
    result[i,i] = 1.T

proc identity3*[T](): TMat3[T] =
  for i in 1..3:
    result[i,i] = 1.T

template identity*(s: int, t: typedesc): expr =
  var x: SquareMatrix[s,t]
  for i in 1..s:
    x[i,i] = t(1)
  x

#vector only code
proc x*(a: TVec): TVec.T = a[1]
proc y*(a: TVec): TVec.T = a[2]
proc z*(a: TVec): TVec.T = a[3]
proc w*(a: TVec): TVec.T = a[4]
proc `x=`*(a: var TVec, val: TVec.T) = a[1] = val
proc `y=`*(a: var TVec, val: TVec.T) = a[2] = val
proc `z=`*(a: var TVec, val: TVec.T) = a[3] = val
proc `w=`*(a: var TVec, val: TVec.T) = a[4] = val
proc xyz*(a: TVec4f): TVec3f = vec3f(a.x, a.y, a.z)

proc norm*(a: TVec): float =
  sqrt(dot(a,a))

proc normalize*(a: TVec): TVec =
  result = a / norm(a)

# Unary plus
proc `+`*(a: TMatrix): TMatrix =
  result = a

# Extended for vectors and matrices
proc `+`*(a, b: TMatrix): TMatrix =
  assert(a.M == b.M)
  assert(a.N == b.N)
  if a.M == 1:
    for i in 1..a.N:
      result[i] = a[i] + b[i]
  else:
    for i in 1..a.N:
      for j in 1..a.M:
        result[i,j] = a[i,j] + b[i,j]

proc `+=`*(a: var TMatrix, b: TMatrix) =
  a = a+b

# Unary minus
# extended for matrices and vectors
proc `-`*(a: TMatrix): TMatrix =
  if a.N == 1:
    for i in 1..a.N:
      result[i] = -a[i]
  else:
    for i in 1..a.N:
      for j in 1..a.M:
        result[i,j] = -a[i,j]

# Simplified to not rewrite
proc `-`*(a, b: TMatrix): TMatrix =
  result = a + (-b)

proc `-=`*(a: var TMatrix, b: TMatrix) =
  a = a-b

proc `-`*(a: TMatrix, c: float): TMatrix =
  if a.M == 1:
    for i in 1..a.N:
      result[i] = a[i] - c
  else:
    for i in 1..a.N:
      for j in 1..a.M:
        result[i,j] = a[i,j] - c

proc `*`*(a: TVec, b: float): TVec =
  if a.M == 1:
    for i in 1..a.N:
      result[i] = a[i] * b
  else:
    for i in 1..a.N:
      for j in 1..a.M:
        result[i,j] = a[i,j] * b

proc `*`*(b: float, a: TVec): TVec = a * b

proc `*=`*(a: var TVec, b: float) = 
  a = a * b

# Extended. Matches matrices and vectors (TMatrix subclass)
proc `==`*(a, b: TMatrix): bool =
  assert(a.N == b.N)
  assert(a.M == b.M)
  result = true
  if a.M == 1:
    # vector
    for i in 1..a.N:
      if a[i] != b[i]:
        return false
  # else a general matrix
  # is it possible to just use this in general?
  # i.e., for j in 1..1 should just do it once.
  # i think it won't just because of the [] operator being different
  else:
    for i in 1..a.N:
      for j in 1..a.M:
        if a[i,j] != b[i,j]:
          return false

# approximately equal to, in case of weird float stuff
proc `~=`*(a, b: TMatrix, tol: float = 1.0e-5): bool =
  assert(a.N == b.M)
  assert(a.M == b.M)
  result = true
  # cehck for exceeding of tolerance
  if a.M == 1:
    # vector
    for i in 1..a.N:
      if abs(a[i] - b[i]) > tol:
        return false
  else:
    for i in 1..a.N:
      for j in 1..a.M:
        if abs(a[i,j] - b[i,j]) > tol:
          return false

proc `<`*(a: TVec, b: TVec): bool =
  result = true
  for i in 1..a.N:
    if a[i] >= b[i]:
      return false

proc `<=`*(a: TVec, b: TVec): bool =
  result = true
  for i in 1..a.N:
    if a[i] > b[i]:
      return false

proc dist*(a,b: TVec): float =
  result = norm(a - b)

proc formatVec3f*(a: TVec3f): string {.noSideEffect.} =
  result  =  "x: " & formatFloat(a[1])
  result &= " y: " & formatFloat(a[2])
  result &= " z: " & formatFloat(a[3])

proc formatVec4f*(a: TVec4f): string {.noSideEffect.} =
  result  =  "x: " & formatFloat(a[1])
  result &= " y: " & formatFloat(a[2])
  result &= " z: " & formatFloat(a[3])
  result &= " w: " & formatFloat(a[4])

proc cross*(u,v: TVec3f): TVec3f =
  result.x = (u.y * v.z) - (u.z * v.y)
  result.y = (u.z * v.x) - (u.x * v.z)
  result.z = (u.x * v.y) - (u.y * v.x)

proc extrema*(vecs: varargs[TVec3f]): tuple[min,max: TVec3f] =
  result.min.x = Inf
  result.min.y = Inf
  result.min.z = Inf
  result.max.x = NegInf
  result.max.y = NegInf
  result.max.z = NegInf
  for vec in vecs:
    if vec.x > result.max.x: result.max.x = vec.x
    elif vec.x < result.min.x: result.min.x = vec.x
    if vec.y > result.max.y: result.max.y = vec.y
    elif vec.y < result.min.y: result.min.y = vec.y
    if vec.z > result.max.z: result.max.z = vec.z
    elif vec.z < result.min.z: result.min.z = vec.z

#transform related code
proc toAffine*(a: TMat3f): TMat4f =
  for i in 1..a.N:
    for j in 1..a.M:
      result[i,j] = a[i,j]
  result[4,4] = 1'f32

proc fromAffine*(a: TMat4f): TMat3f =
  for i in 1..3:
    for j in 1..3:
      result[i,j] = a[i,j]

proc toTranslationMatrix*(v: TVec3f): TMat4f =
  result = identity4f()
  result[1,4] = v[1]
  result[2,4] = v[2]
  result[3,4] = v[3]

proc fromTranslationMtx*(m: TMat4f): TVec3f =
  result[1] = m[1,4]
  result[2] = m[2,4]
  result[3] = m[3,4]

proc unProject*(win: TVec3f; mtx: TMat4f, viewport: TVec4f): TVec3f =
  var inversevp = inverse(mtx)
  var tmp = vec4f(win, 1'f32)
  tmp[1] = (tmp[1] - viewport[1]) / viewport[3]
  tmp[2] = (tmp[2] - viewport[2]) / viewport[4]
  tmp = (tmp * 2'f32) - 1'f32
  var obj = mul4v(inversevp, tmp)
  obj = obj / obj[4]
  result = vec3f(obj[1], obj[2], obj[3])

proc unProject*(win: TVec3f; view, proj: TMat4f; viewport: TVec4f): TVec3f =
  unProject(win, mul(proj, view), viewport)

#projection related code
proc CreateOrthoMatrix*(min, max: TVec3f): TMat4f =
  var sx = 2 / (max.x - min.x)
  var sy = 2 / (max.y - min.y)
  var sz = 2 / (max.z - min.z)
  var tx = -( max.x + min.x )/( max.x - min.x )
  var ty = -( max.y + min.y )/( max.y - min.y )
  var tz = -( max.z + min.z )/( max.z - min.z )
  result.data = [sx, 0,   0,    0,
                 0,  sy,  0,    0,
                 0,  0,   sz,   0,
                 tx,  ty, tz,   1]

proc CreateOrthoMatrix*(box: TAlignedBox3f): TMat4f =
  result = CreateOrthoMatrix(box.min, box.max)

proc CreateOrthoMatrix*(left, right, bottom, top, near, far: float32): TMat4f =
  ## this works just like glOrtho
  result.data = [2/(right - left), 0, 0, 0,
                 0, 2/(top-bottom), 0, 0,
                 0, 0, -2 / (far - near), 0,
                 -(right + left)/(right - left), -(top+bottom)/(top-bottom), 
                 -2 * ((far + near)/(far - near)), 1]

#quaternion related code
proc `[]`*(self: TQuatf; i: int): float32 = array[1..4, float32](self)[i]
proc `[]=`*(self: var TQuatf; i: int; val: float32) = array[1..4,float32](self)[i] = val
proc `==`*(a,b: TQuatf): bool {.borrow.}
proc i*(q: TQuatf): float32 = q[2]
proc j*(q: TQuatf): float32 = q[3]
proc k*(q: TQuatf): float32 = q[4]
proc w*(q: TQuatf): float32 = q[1]
proc `i=`*(q: var TQuatf, val: float32) = q[2] = val
proc `j=`*(q: var TQuatf, val: float32) = q[3] = val
proc `k=`*(q: var TQuatf, val: float32) = q[4] = val
proc `w=`*(q: var TQuatf, val: float32) = q[1] = val
proc x*(q: TQuatf): float32 = q[2]
proc y*(q: TQuatf): float32 = q[3]
proc z*(q: TQuatf): float32 = q[4]
proc mul*(p: TQuatf, q: TQuatf): TQuatf

proc `$`*(q: TQuatf): string =
  # w + xi + yj + zk
  result = "\n" & $q.w & " + " & $q.i &
            "i + " & $q.j & "j + " & $q.k & "k\n"

proc `/`*(q: TQuatf, s: float): TQuatf =
  result.i = q.i / s
  result.j = q.j / s
  result.k = q.k / s
  result.w = q.w / s

proc `/`*(q: TQuatf, s: float32): TQuatf = q / s.float

proc quatf*(w,i,j,k: float32): TQuatf = [w,i,j,k].TQuatf

proc toVector(q: TQuatf): TVec4f =
  result.data = array[0..3, float32](q)

proc norm*(q: TQuatf): float = norm(toVector(q))

proc normalize*(q: TQuatf): TQuatf = q / norm(q)

proc conj*(q: TQuatf): TQuatf =
  result.i = -q.i
  result.j = -q.j
  result.k = -q.k
  result.w = q.w

proc inverse*(q: TQuatf): TQuatf =
  result = conj(q)
  result = result / mul(q, conj(q)).w

proc mul*(p: TQuatf; q: TQuatf): TQuatf =
  result[1] = p.w * q.w - p.x * q.x - p.y * q.y - p.z * q.z;
  result[2] = p.w * q.x + p.x * q.w + p.y * q.z - p.z * q.y;
  result[3] = p.w * q.y + p.y * q.w + p.z * q.x - p.x * q.z;
  result[4] = p.w * q.z + p.z * q.w + p.x * q.y - p.y * q.x;

proc mulv*(q: TQuatf; v: TVec3f): TVec3f =
  var qv = quatf(0, v.x, v.y, v.z)
  var prod = mul(q, mul(qv, conj(q)))
  result = vec3f(prod.i, prod.j, prod.k)

proc mul*(p: TQuatf; a: TAlignedBox3f): TAlignedBox3f =
  var rotmin = mulv(p, a.min)
  var rotmax = mulv(p, a.max)
  for i in 1..3:
    result.min[i] = min(a.min[i], rotmin[i])
    result.max[i] = max(a.max[i], rotmax[i])

proc toRotMatrix*(q: TQuatf): TMat3f =
  # quaternion to rotation matrix, regardless of whether we
  # start from a unit quaternion
  var n = q.w*q.w + q.x*q.x + q.y*q.y + q.z*q.z
  # poor test for a norm of 0
  var s = if (n == 0.0): 0.0 else: 2/n
  var wx = s*q.w*q.x
  var wy = s*q.w*q.y
  var wz = s*q.w*q.z
  var xx = s*q.x*q.x
  var xy = s*q.x*q.y
  var xz = s*q.x*q.z
  var yy = s*q.y*q.y
  var yz = s*q.y*q.z
  var zz = s*q.z*q.z
  result[1,1] = 1'f32 - (yy + zz)
  result[1,2] = xy - wz
  result[1,3] = xz + wy
  result[2,1] = xy + wz
  result[2,2] = 1'f32 - (xx + zz)
  result[2,3] = yz - wx
  result[3,1] = xz - wy
  result[3,2] = yz + wx
  result[3,3] = 1'f32 - (xx + yy)

proc fromRotMatrix*(m: TMat3f): TQuatf =
  ## convert a rotation matrix into a quaternion
  ## this algorithm comes from the Eigen linear algebra
  ## library which in turn credits it to Ken Shoemake
  var t = trace(m)
  if t > 0:
    t = sqrt(t + 1.0)
    result.w = 0.5 * t
    t = 0.5/t
    result.i = (m[3,2] - m[2,3]) * t
    result.j = (m[1,3] - m[3,1]) * t
    result.k = (m[2,1] - m[1,2]) * t
  else:
    var i = 1
    if m[2,2] > m[1,1]:
      i = 2
    if m[3,3] > m[i,i]:
      i = 3
    var j = (i+1) mod 3
    var k = (j+1) mod 3
    inc(j)
    inc(k)
    t = sqrt(m[i,i] - m[j,j] - m[k,k] + 1.0)
    result[i] = 0.5 * t
    t = 0.5 / t
    result.w = (m[k,j] - m[j,k]) * t
    result[j] = (m[j,i] + m[i,j]) * t
    result[k] = (m[k,i] + m[i,k]) * t

proc toOrbitRotMatrix*(q: TQuatf, pos: TVec3f): TMat4f =
  result = toTranslationMatrix(-1 * pos)
  result = mul(result, toAffine(toRotMatrix(q)))
  result = mul(result, toTranslationMatrix(pos))

proc quatFromAngleAxis*(angle: float; axis: TVec3f): TQuatf =
  var vecScale = sin(0.5 * angle)
  result[2] = axis[1] * vecScale
  result[3] = axis[2] * vecScale
  result[4] = axis[3] * vecScale
  result[1] = cos(0.5 * angle)

proc quatFromTwoVectors*(v,w: TVec3f): TQuatf =
  var v = normalize(v)
  var w = normalize(w)
  var c = normalize(cross(v,w))
  result.i = c.x
  result.j = c.y
  result.k = c.z
  result.w = 1 + dot(v,w)

proc identityQuatf*(): TQuatf =
  result[1] = 1.0'f32
  result[2] = 0.0'f32
  result[3] = 0.0'f32
  result[4] = 0.0'f32

#AABB related code
proc contains*(aabb: TAlignedBox3f, target: TAlignedBox3f): bool =
  if (target.min >= aabb.min) and (target.min <= aabb.max):
    return true
  if (target.max <= aabb.max) and (target.max >= aabb.min):
    return true
  return false

proc encloses*(aabb: TAlignedBox3f, target: TAlignedBox3f): bool =
  if (target.min >= aabb.min) and (target.max <= aabb.max):
    return true
  return false

proc extend*(aabb: var TAlignedBox3f, target: TVec3f) =
  for i in 1..3:
    if target[i] < aabb.min[i]: aabb.min[i] = target[i]
    if target[i] > aabb.max[i]: aabb.max[i] = target[i]

proc extend*(aabb: var TAlignedBox3f, target: TAlignedBox3f) =
  for i in 1..3:
    if target.min[i] < aabb.min[i]: aabb.min[i] = target.min[i]
    if target.max[i] > aabb.max[i]: aabb.max[i] = target.max[i]
  #assert(target in aabb)

proc corner*(aabb: TAlignedBox3f, which: TCornerType): TVec3f =
  var mult = 1.uint
  for i in 1..3:
    if (mult and which.uint) > 0.uint: result[i] = aabb.max[i]
    else: result[i] = aabb.min[i]
    mult = mult * 2

proc split*(aabb: TAlignedBox3f, axis: TAxis): tuple[a,b: TAlignedBox3f] =
  result.a = aabb
  result.b = aabb
  var axisIdx = axis.int
  var diff = aabb.max - aabb.min
  result.a.min[axisIdx] = result.a.min[axisIdx] + (diff[axisIdx] / 2)
  result.b.max[axisIdx] = result.b.max[axisIdx] - (diff[axisIdx] / 2)

proc split*(aabb: TAlignedBox3f, axis: TAxis; a,b: var TAlignedBox3f) =
  var (tmpa, tmpb) = split(aabb, axis)
  a = tmpa
  b = tmpb

proc split*(aabb: TAlignedBox3f): array[1..8, TAlignedBox3f] =
  split(aabb, axisYZ, result[1], result[3])
  split(result[1], axisXZ, result[1], result[2])
  split(result[3], axisXZ, result[3], result[4])
  split(result[1], axisXY, result[1], result[5])
  split(result[2], axisXY, result[2], result[6])
  split(result[3], axisXY, result[3], result[7])
  split(result[4], axisXY, result[4], result[8])

proc centroid*(aabb: TAlignedBox3f): TVec3f =
  result = (aabb.min + aabb.max) / 2

proc mulArea*(aabb: TAlignedBox3f, mat: TMat4f): TAlignedBox3f =
  ## multiplies the aabb by the matrix and preserves the area
  ## this means that it is not "real" matrix multiplication, but
  ## rather multiplication of each corner of the AABB by the matrix
  ## followed by a reconstruction of the aabb
  var transformedPoints: array[1..8, TVec3f]
  for i in 1..8:
    var corner = aabb.corner(TCornerType(i-1))
    transformedPoints[i] = vec3f(mul4v(mat, vec4f(corner, 1)))
  var minmax = extrema(transformedPoints)
  result.min = minmax.min
  result.max = minmax.max

proc `$`*(aabb: TAlignedBox3f): string {.noSideEffect.} =
  result = "min: " & formatVec3f(aabb.min) & "\nmax: " & formatVec3f(aabb.max)

#this ray has more information
#than TRay, for fast slope based intersections
type TRayClassification = enum
  MMM,MMP,MPM,MPP,PMM,PMP,PPM,PPP,POO,MOO,OPO,OMO,OOP,OOM,
  OMM,OMP,OPM,OPP,MOM,MOP,POM,POP,MMO,MPO,PMO,PPO
type TIntersectRay* = object
  class: TRayClassification
  x,y,z: float
  i,j,k: float
  ii,ij,ik:float
  ibyj,jbyi,kbyj,jbyk,ibyk,kbyi: float
  c_xy,c_yx,c_zy,c_yz,c_xz,c_zx: float

proc Precompute_Ray*(ray: TRay): TIntersectRay =
  const XXX = {MMM,MMP,MPM,MPP,PMM,PMP,PPM,PPP,POO,MOO,OPO,OMO,OOP,OOM,
               OMM,OMP,OPM,OPP,MOM,MOP,POM,POP,MMO,MPO,PMO,PPO}
  const MXX = {MMM,MMP,MPM,MPP,MOO,MOM,MOP,MMO,MPO}
  const PXX = {PMM,PMP,PPM,PPP,POO,POM,POP,PMO,PPO}
  const OXX = {OPO,OMO,OOP,OOM,OMM,OMP,OPM,OPP}
  const XMX = {MMM,MMP,PMM,PMP,OMO,OMM,OMP,MMO,PMO}
  const XPX = {MPM,MPP,PPM,PPP,OPO,OPM,OPP,MPO,PPO}
  const XOX = {POO,MOO,OOP,OOM,MOM,MOP,POM,POP}
  const XXM = {MMM,MPM,PMM,PPM,OOM,OMM,OPM,MOM,POM}
  const XXP = {MMP,MPP,PMP,PPP,OOP,OMP,OPP,MOP,POP}
  const XXO = {POO,MOO,OPO,OMO,MMO,MPO,PMO,PPO}
  result.x = ray.origin.x
  result.y = ray.origin.y
  result.z = ray.origin.z
  result.i = ray.dir.x
  result.j = ray.dir.y
  result.k = ray.dir.z
  result.ii = 1.0/result.i
  result.ij = 1.0/result.j
  result.ik = 1.0/result.k
  result.ibyj = result.i * result.ij
  result.jbyi = result.j * result.ii
  result.jbyk = result.j * result.ik
  result.kbyj = result.k * result.ij
  result.ibyk = result.i * result.ik
  result.kbyi = result.k * result.ii
  result.c_xy = result.y - result.jbyi * result.x
  result.c_yx = result.x - result.kbyi * result.y
  result.c_zy = result.y - result.ibyj * result.z
  result.c_yz = result.z - result.kbyj * result.y
  result.c_xz = result.z - result.ibyk * result.x
  result.c_zx = result.x - result.jbyk * result.z
  
  var possibleClass: set[TRayClassification] = XXX
  #the paper does this with if statements, but I like this way much better
  
  if result.i < 0: possibleClass = possibleClass * MXX
  elif result.i == 0: possibleClass = possibleClass * OXX
  else: possibleClass = possibleClass * PXX
  
  if result.j < 0: possibleClass = possibleClass * XMX
  elif result.j == 0: possibleClass = possibleClass * XOX
  else: possibleClass = possibleClass * XPX
  
  if result.k < 0: possibleClass = possibleClass * XXM
  elif result.k == 0: possibleClass = possibleClass * XXO
  else: possibleClass = possibleClass * XXP
  
  assert(card(possibleClass) == 1)
  var intVal = cast[int64](possibleClass)
  var idx: uint32 = 0
  
  BitScanForward64(addr idx, intVal)
  result.class = cast[TRayClassification](idx)


proc intersects*(r: TIntersectRay, b: TAlignedBox3f): bool =
  result = false

  case r.class
  of MMM:
    if (r.x < b.min.x) or (r.y < b.min.y) or (r.z < b.min.z) or 
      (r.jbyi * b.min.x - b.max.y + r.c_xy > 0) or 
      (r.ibyj * b.min.y - b.max.x + r.c_yx > 0) or 
      (r.jbyk * b.min.z - b.max.y + r.c_zy > 0) or 
      (r.kbyj * b.min.y - b.max.z + r.c_yz > 0) or 
      (r.kbyi * b.min.x - b.max.z + r.c_xz > 0) or 
      (r.ibyk * b.min.z - b.max.x + r.c_zx > 0): return false
    return true
  of MMP:
    if (r.x < b.min.x) or (r.y < b.min.y) or (r.z > b.max.z) or 
      (r.jbyi * b.min.x - b.max.y + r.c_xy > 0) or
      (r.ibyj * b.min.y - b.max.x + r.c_yx > 0) or
      (r.jbyk * b.max.z - b.max.y + r.c_zy > 0) or
      (r.kbyj * b.min.y - b.min.z + r.c_yz < 0) or
      (r.kbyi * b.min.x - b.min.z + r.c_xz < 0) or
      (r.ibyk * b.max.z - b.max.x + r.c_zx > 0): return false
    return true
  of MPM:
    if (r.x < b.min.x) or (r.y > b.max.y) or (r.z < b.min.z) or
      (r.jbyi * b.min.x - b.min.y + r.c_xy < 0) or
      (r.ibyj * b.max.y - b.max.x + r.c_yx > 0) or
      (r.jbyk * b.min.z - b.min.y + r.c_zy < 0) or
      (r.kbyj * b.max.y - b.max.z + r.c_yz > 0) or
      (r.kbyi * b.min.x - b.max.z + r.c_xz > 0) or
      (r.ibyk * b.min.z - b.max.x + r.c_zx > 0): return false
    return true
  of MPP:
    if (r.x < b.min.x) or (r.y > b.max.y) or (r.z > b.max.z) or
      (r.jbyi * b.min.x - b.min.y + r.c_xy < 0) or
      (r.ibyj * b.max.y - b.max.x + r.c_yx > 0) or
      (r.jbyk * b.max.z - b.min.y + r.c_zy < 0) or
      (r.kbyj * b.max.y - b.min.z + r.c_yz < 0) or
      (r.kbyi * b.min.x - b.min.z + r.c_xz < 0) or
      (r.ibyk * b.max.z - b.max.x + r.c_zx > 0): return false
    return true
  of PMM:
    if (r.x > b.max.x) or (r.y < b.min.y) or (r.z < b.min.z) or
      (r.jbyi * b.max.x - b.max.y + r.c_xy > 0) or
      (r.ibyj * b.min.y - b.min.x + r.c_yx < 0) or
      (r.jbyk * b.min.z - b.max.y + r.c_zy > 0) or
      (r.kbyj * b.min.y - b.max.z + r.c_yz > 0) or
      (r.kbyi * b.max.x - b.max.z + r.c_xz > 0) or
      (r.ibyk * b.min.z - b.min.x + r.c_zx < 0): return false
    return true
  of PMP:
    if (r.x > b.max.x) or (r.y < b.min.y) or (r.z > b.max.z) or
      (r.jbyi * b.max.x - b.max.y + r.c_xy > 0) or
      (r.ibyj * b.min.y - b.min.x + r.c_yx < 0) or
      (r.jbyk * b.max.z - b.max.y + r.c_zy > 0) or
      (r.kbyj * b.min.y - b.min.z + r.c_yz < 0) or
      (r.kbyi * b.max.x - b.min.z + r.c_xz < 0) or
      (r.ibyk * b.max.z - b.min.x + r.c_zx < 0): return false
    return true
  of PPM:
    if (r.x > b.max.x) or (r.y > b.max.y) or (r.z < b.min.z) or
      (r.jbyi * b.max.x - b.min.y + r.c_xy < 0) or
      (r.ibyj * b.max.y - b.min.x + r.c_yx < 0) or
      (r.jbyk * b.min.z - b.min.y + r.c_zy < 0) or
      (r.kbyj * b.max.y - b.max.z + r.c_yz > 0) or
      (r.kbyi * b.max.x - b.max.z + r.c_xz > 0) or
      (r.ibyk * b.min.z - b.min.x + r.c_zx < 0): return false
    return true
  of PPP:
    if (r.x > b.max.x) or (r.y > b.max.y) or (r.z > b.max.z) or
      (r.jbyi * b.max.x - b.min.y + r.c_xy < 0) or
      (r.ibyj * b.max.y - b.min.x + r.c_yx < 0) or
      (r.jbyk * b.max.z - b.min.y + r.c_zy < 0) or
      (r.kbyj * b.max.y - b.min.z + r.c_yz < 0) or
      (r.kbyi * b.max.x - b.min.z + r.c_xz < 0) or
      (r.ibyk * b.max.z - b.min.x + r.c_zx < 0): return false
    return true
  of OMM:
    if (r.x < b.min.x) or (r.x > b.max.x) or
      (r.y < b.min.y) or (r.z < b.min.z) or
      (r.jbyk * b.min.z - b.max.y + r.c_zy > 0) or
      (r.kbyj * b.min.y - b.max.z + r.c_yz > 0): return false
    return true
  of OMP:
    if (r.x < b.min.x) or (r.x > b.max.x) or
      (r.y < b.min.y) or (r.z > b.max.z) or
      (r.jbyk * b.max.z - b.max.y + r.c_zy > 0) or
      (r.kbyj * b.min.y - b.min.z + r.c_yz < 0): return false
    return true
  of OPM:
    if (r.x < b.min.x) or (r.x > b.max.x) or
      (r.y > b.max.y) or (r.z < b.min.z) or
      (r.jbyk * b.min.z - b.min.y + r.c_zy < 0) or
      (r.kbyj * b.max.y - b.max.z + r.c_yz > 0): return false
    return true
  of OPP:
    if (r.x < b.min.x) or (r.x > b.max.x) or
      (r.y > b.max.y) or (r.z > b.max.z) or
      (r.jbyk * b.max.z - b.min.y + r.c_zy < 0) or
      (r.kbyj * b.max.y - b.min.z + r.c_yz < 0) :return false
    return true
  of MOM:
    if (r.y < b.min.y) or (r.y > b.max.y) or
      (r.x < b.min.x) or (r.z < b.min.z)  or
      (r.kbyi * b.min.x - b.max.z + r.c_xz > 0) or
      (r.ibyk * b.min.z - b.max.x + r.c_zx > 0): return false
    return true
  of MOP:
    if (r.y < b.min.y) or (r.y > b.max.y) or
      (r.x < b.min.x) or (r.z > b.max.z) or
      (r.kbyi * b.min.x - b.min.z + r.c_xz < 0) or
      (r.ibyk * b.max.z - b.max.x + r.c_zx > 0): return false
    return true
  of POM:
    if (r.y < b.min.y) or (r.y > b.max.y) or
      (r.x > b.max.x) or (r.z < b.min.z) or
      (r.kbyi * b.max.x - b.max.z + r.c_xz > 0) or
      (r.ibyk * b.min.z - b.min.x + r.c_zx < 0): return false
    return true
  of POP:
    if (r.y < b.min.y) or (r.y > b.max.y) or
      (r.x > b.max.x) or (r.z > b.max.z) or
      (r.kbyi * b.max.x - b.min.z + r.c_xz < 0) or
      (r.ibyk * b.max.z - b.min.x + r.c_zx < 0): return false
    return true
  of MMO:
    if (r.z < b.min.z) or (r.z > b.max.z) or
      (r.x < b.min.x) or (r.y < b.min.y)  or
      (r.jbyi * b.min.x - b.max.y + r.c_xy > 0) or
      (r.ibyj * b.min.y - b.max.x + r.c_yx > 0): return false
    return true
  of MPO:
    if (r.z < b.min.z) or (r.z > b.max.z) or
      (r.x < b.min.x) or (r.y > b.max.y) or
      (r.jbyi * b.min.x - b.min.y + r.c_xy < 0) or
      (r.ibyj * b.max.y - b.max.x + r.c_yx > 0): return false
    return true
  of PMO:
    if (r.z < b.min.z) or (r.z > b.max.z) or
      (r.x > b.max.x) or (r.y < b.min.y)  or
      (r.jbyi * b.max.x - b.max.y + r.c_xy > 0) or
      (r.ibyj * b.min.y - b.min.x + r.c_yx < 0): return false
    return true
  of PPO:
    if (r.z < b.min.z) or (r.z > b.max.z) or
      (r.x > b.max.x) or (r.y > b.max.y) or
      (r.jbyi * b.max.x - b.min.y + r.c_xy < 0) or
      (r.ibyj * b.max.y - b.min.x + r.c_yx < 0): return false
    return true
  of MOO:
    if (r.x < b.min.x) or
      (r.y < b.min.y) or (r.y > b.max.y) or
      (r.z < b.min.z) or (r.z > b.max.z): return false
    return true
  of POO:
    if (r.x > b.max.x) or
      (r.y < b.min.y) or (r.y > b.max.y) or
      (r.z < b.min.z) or (r.z > b.max.z): return false
    return true
  of OMO:
    if (r.y < b.min.y) or
      (r.x < b.min.x) or (r.x > b.max.x) or
      (r.z < b.min.z) or (r.z > b.max.z): return false
    return true
  of OPO:
    if (r.y > b.max.y) or
      (r.x < b.min.x) or (r.x > b.max.x) or
      (r.z < b.min.z) or (r.z > b.max.z): return false
    return true
  of OOM:
    if (r.z < b.min.z) or
      (r.x < b.min.x) or (r.x > b.max.x) or
      (r.y < b.min.y) or (r.y > b.max.y): return false
    return true
  of OOP:
    if (r.z > b.max.z) or
      (r.x < b.min.x) or (r.x > b.max.x) or
      (r.y < b.min.y) or (r.y > b.max.y): return false
    return true

proc intersects*(r: TRay, b: TAlignedBox3f): bool =
  result = intersects(Precompute_Ray(r), b)

# frustum related code, for culling and
# other stuff
type TPlane* = distinct TVec4f
type TNormalPlane* = distinct TVec4f

proc extractPlane*(matrix: TMat4f, side, sign: int): TPlane =
  ## extract a frustum plane from a matrix
  ## the side and sign parameters determine
  ## which row vector is used and weather it is added
  ## or subtracted from the last row vector
  result = TPlane(matrix.row(4) + float(sign)*matrix.row(side))

proc extractPlane*(matrix: TMat4f, plane: int): TPlane =
  assert(plane > 0)
  assert(plane < 7)
  var sgn = plane mod 2
  if sgn > 0: sgn = -1
  else: sgn = 1
  result = extractPlane(matrix, (plane div 2) + 1, sgn)

proc toHessianNormalForm*(plane: TPlane): TNormalPlane =
  var asq = pow(TVec4f(plane).x, 2)
  var bsq = pow(TVec4f(plane).y, 2)
  var csq = pow(TVec4f(plane).z, 2)
  var denom = sqrt(asq + bsq + csq)
  result = (plane.TVec4f / denom).TNormalPlane

proc distance(plane: TNormalPlane, point: TVec3f): float =
  var plane = plane.TVec4f
  var normVec = vec3f(plane.x, plane.y, plane.z)
  result = dot(normVec, point) + plane.w

proc frustumContains*(frustum: TMat4f, box: TAlignedBox3f): bool =
  result = true
  for i in 1..6:
    var numOut: int = 0
    var numIn: int = 0
    var plane = toHessianNormalForm(extractPlane(frustum, i))
    for k in 1..8:
      if not ((numIn == 0) or (numOut == 0)): break
      if plane.distance(box.corner((k-1).TCornerType)) < 0:
        inc(numOut)
      else:
        inc(numIn)
    if numIn == 0:
      return false

      
discard """
const XSwiz = {'x', 'r', 'u' }
const YSwiz = {'y', 'g', 'v' }
const ZSwiz = {'z', 'b', 'w' }
const WSwiz = {'w', 'a'}
proc `.`*[N: static[int]; T](self: TVec[N, T]; field: static[string]): TVec[field.len, T] =
  for i in 1..field.len:
    if field[i-1] in XSwiz:
      result[i] = self[1]
    if field[i-1] in YSwiz:
      result[i] = self[2]
    if field[i-1] in ZSwiz:
      result[i] = self[3]
    if field[i-1] in WSwiz:
      result[i] = self[4]
"""
#directly graphics related functions, like ports of glu stuff and the like, 
proc LookAt*(eye, center, up: TVec3f): TMat4f =
  ## makes a viewing matrix that looks at a given object from a given center
  ## and "up" point, this works like gluLookAt but returns a matrix instead
  ## of messing with the old matrix stack.
  var forward = center - eye
  forward = normalize(forward)
  var side = cross(forward, up)
  side = normalize(side)
  var up = cross(side, forward)
  result = identity4f()
  result[1,1] = side[1]
  result[2,1] = side[2]
  result[3,1] = side[3]

  result[1,2] = up[1]
  result[2,2] = up[2]
  result[3,2] = up[3]
  
  result[1,3] = -1 * forward[1]
  result[2,3] = -1 * forward[2]
  result[3,3] = -1 * forward[3]
  result = result.transpose()
  var eyeTrans = toTranslationMatrix(-1 * eye)
  result = mul(eyeTrans, result)

when isMainModule:

  import unittest

  test "TIdentity":
    var ta = identity4[int]()
    check(ta[1,1] == 1)
    var tb = identity4[float32]()
    check(tb[1,1] == 1'f32)

  test "TGenIdentity":
    var ta = identity(3, int)
    check(ta[2,2] == 1)
    var tb = identity(4, float)
    check(tb[3,3] == 1.0)

  test "TMatTranspose":
    var ta: TMat4f
    ta[2,3] = 1.0'f32
    var tb = ta.transpose
    check(tb[3,2] == 1.0'f32)

  test "TLessThan":
    var av = vec3f(0,0,0)
    var bv = vec3f(1,1,1)
    check(av < bv)
  
  test "TNotLessThan":
    var av = vec3f(1,1,1)
    var bv = vec3f(0,1,0)
    check(not (av > bv))
    check(not (av < bv))
  
  test "TExtend":
    var aabb: TAlignedBox3f
    var av = vec3f(5,5,5)
    aabb.extend(av)
    check(aabb.max == av)
  
  test "TDotProduct":
    var av: TVec3f
    av.data = [1.0'f32, 2.0'f32, 0.0'f32]
    var bv: TVec3f
    bv.data = [0.0'f32, 5.0'f32, 1.0'f32]
    var cv = dot(av,bv)
    check(cv == 10.0'f32)
  
  test "TCross1":
    var a = vec3f(1,0,0)
    var b = vec3f(0,1,0)
    var c = cross(a,b)
    check(c == vec3f(0,0,1))
  
  test "TRow":
    var ta: TMat4f
    ta[1,1] = 1.0'f32
    var tr = ta.row(1)
    check(tr.data == [1'f32, 0'f32, 0'f32, 0'f32])
  
  test "TColumn":
    var ta: TMat4f
    ta[1,1] = 1.0'f32
    var tc = ta.col(1)
    check(tc.data == [1.0'f32, 0.0'f32, 0.0'f32, 0.0'f32])
  
  test "TMul":
    var ta: TMat4f
    ta[1,2] = 2.0'f32
    var tb: TMat4f
    tb[2,1] = 2.0'f32
  #  discard mul(ta, tb)
  
  test "TestMat3f":
    var tm3: TMat3f
    var tm4 = toAffine(tm3)
    check(tm4[4,4] == 1.0'f32)
  
  test "Test Construct":
    #I actually had a bug where constructors just stopped working
    var vec4: TVec4f = vec4f(1.0'f32, 1.0'f32, 1.0'f32, 1.0'f32)
    check(vec4.data == [1.0'f32, 1.0'f32, 1.0'f32, 1.0'f32])
  
  test "TSub":
    var a = initMat3f([1'f32,2'f32,3'f32,
                       4'f32,5'f32,6'f32,
                       7'f32,8'f32,9'f32])
    var c = initMat2f([1'f32, 3'f32,
                       7'f32, 9'f32])
    var b:TMat2f = a.sub(2,2)
    var e:bool = b == c
    check(e)
  
  test "TDet2x2":
    var a = initMat2f([1'f32,2'f32,3'f32,4'f32])
    var da = det(a)
    check(da == -2'f32)
  
  test "TDet3x3f":
    var a = initMat3f([1'f32, 2'f32, 3'f32, 
                       4'f32, 5'f32, 6'f32,
                       7'f32, 8'f32, 9'f32])
    var da = det(a)
    check(da == 0.0)
  
  # TODO: Make generic adj() proc to handle any case correctly
  test "TAdj3x3":
    var a = initMat3f([1'f32, 2'f32, 3'f32, 
                               4'f32, 5'f32, 6'f32,
                               7'f32, 8'f32, 9'f32])
    var aj = adj3(a)
    var b = initMat3f([-3'f32, 6'f32, -3'f32,
                        6'f32, -12'f32, 6'f32,
                        -3'f32, 6'f32, -3'f32])
    var e = aj == b
    check(e)
  
  test "TMatToQuat1":
    var rot = quatFromAngleAxis(0.5, vec3f(1,0,0))
    var mtx = toRotMatrix(rot)
    var newRot = fromRotMatrix(mtx)
    check(newRot == rot)
  discard """ 
  test "TSwizzle":
    var ta: TVec3f = TVec3f(data: [1.0'f32, 2.0'f32, 3.0'f32])
    check(ta.xxx == TVec3f(data: [1.0'f32, 1.0'f32, 1.0'f32] ))
  """
  #check(prod[1,1] == 8.0'f32)
  #check(prod[1,2] == 5.0'f32)
  #check(prod[2,1] == 20.0'f32)
  #check(prod[2,2] == 13.0'f32)
  

