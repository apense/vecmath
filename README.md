vecmath
=======

Vector and graphics maths for nimrod

Example
-------

To make a 4x4 float matrix, give it some sample values, and print out its transpose, we can do:

```nimrod
var tf: TMat4f
# note that x[i,j] references the ith row, jth column in x
tf[2,1] = 0.4
tf[1,3] = 1.5
tf = tf.transpose # actually transpose the matrix
echo tf # note that tf[1,2] == 0.4 and tf[3,1] == 1.5
#
# [ 0.0 0.4 0.0 0.0 ]
# [ 0.0 0.0 0.0 0.0 ]
# [ 1.5 0.0 0.0 0.0 ]
# [ 0.0 0.0 0.0 0.0 ]
#
```

You can get different types of identity matrices. Some sizes are predefined.
However, assuming you just want an NxN identity matrix of type T, just run
`identity(N, T)`. For example:

```nimrod
var ti = identity(4, int) # gives a 4x4 matrix with diagonals == 1
```


Quaternions are also defined as float vectors of length 4.