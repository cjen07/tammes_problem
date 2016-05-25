defmodule Tammes do

  # helper function

  def call(args, fun) do
    apply(fun, args)
  end

  def call(args, fun, module) do
    apply(module, fun, args)
  end

  def vector_fun(e1, e2, fun) do
    Enum.zip(e1, e2)
    |> Enum.map(&Tuple.to_list(&1))
    |> Enum.map(&call(&1, fun))
  end

  def dot_product(c1, c2) do
    vector_fun(c1, c2, &(&1*&2)) |> Enum.sum
  end

  def vector_add(c1, c2) do
    vector_fun(c1, c2, &(&1+&2))
  end

  def vector_minus(c1, c2) do
    vector_fun(c1, c2, &(&1-&2))
  end

  def vector_k(c, k) do
    c |> Enum.map(&(k*&1))
  end

  def vector_norm(c, k \\ 2) do
    c 
    |> Enum.map(&(:math.pow(&1, k))) 
    |> Enum.sum 
    |> :math.pow(1/k)
  end

  def vector_unit(c) do
    k = vector_norm(c)
    vector_k(c, 1/k)
  end

  # sphere functions

  def angle_to_xyz(point) do
    [theta, phi] = point
    s_t = :math.sin theta
    c_t = :math.cos theta
    s_p = :math.sin phi
    c_p = :math.cos phi
    [s_p*c_t, s_p*s_t, c_p]
  end

  def xyz_to_angle(c) do
    n = vector_norm(c)
    [x, y, z] = c
    phi = :math.acos z/n
    s_t = y/n/(:math.sin phi) |> max(-1) |> min(1)
    c_t = x/n/(:math.sin phi) |> max(-1) |> min(1)
    theta =
    cond do
      s_t > 0 -> :math.acos c_t
      c_t > 0 -> :math.asin s_t
      true -> -:math.pi - :math.asin s_t
    end
    [theta, phi]
  end

  def arc_distance(point1, point2) do
    [point1, point2] 
    |> Enum.map(&angle_to_xyz(&1))
    |> call(:dot_product, Tammes) 
    |> min(1)
    |> max(-1)
    |> :math.acos 
  end

  def project(p, c1, c2, c3) do
    c = angle_to_xyz(p)
    k = dot_product(c1, c) |> min(1) |> max(-1)
    phi = :math.acos k
    c4 = vector_minus(c, vector_k(c1, k)) |> vector_unit
    c_2 = dot_product(c2, c4) |> min(1) |> max(-1)
    c_3 = dot_product(c3, c4) |> min(1) |> max(-1)
    theta = 
    cond do
      c_3 > 0 -> :math.acos c_2
      true -> -(:math.acos c_2)        
    end
    [theta, phi]
  end

  def change(v, i, n \\ 15, range \\ [0.935, 0.937]) do
    p = Enum.at(v, i)
    v = List.delete_at(v, i)

    c1 = [x, y, z] = angle_to_xyz(p)
    c2 = [z, 0, -x] |> vector_unit
    c3 = [x, -(x*x+z*z)/y, z] |> vector_unit

    v = v |> Enum.map(&(project(&1, c1, c2, c3))) |> Enum.into([[0,0]])

    [a, b] = range
    k = for x <- 0..n-1, y <- 0..n-1, x < y, do: {x, y, Tammes.arc_distance(Enum.at(v, x), Enum.at(v, y))}
    k = k |> Enum.filter(fn {_, _, d} -> d > a and d < b end)
          |> Enum.map(fn {x, y, _} -> [x, y] end)

    pi = :math.pi
    IO.inspect v = v |> Enum.map(fn [x, y] -> [x/pi*180, 90 - y/pi*180] end)
    IO.inspect k |> Enum.map(fn [i, j] -> [Enum.at(v, i), Enum.at(v, j)] end)
    :ok
  end



  # model functions

  # algorithm1

  def force(p1, p2, rate \\ -36) do
    c1 = angle_to_xyz(p1)
    c2 = angle_to_xyz(p2)
    
    c3 = vector_minus(c1, c2)
    c4 = vector_k(c3, c3 |> vector_norm |> :math.pow(rate-1))

    vector_minus(c4, vector_k(c1, dot_product(c1, c4)))
  end

  def move(v, index, step \\ 1.0e-8) do
    List.delete_at(v, index)
    |> Enum.map(&(force(Enum.at(v, index), &1)))
    |> List.foldr([0,0,0], &(vector_add(&1, &2)))
    |> Enum.map(&(&1*step))

  end

  def step(bucket, n) do
    v = values(bucket)
    0..n-1
    |> Enum.map(&(xyz_to_angle(vector_add(angle_to_xyz(Enum.at(v, &1)), move(v, &1)))))
    |> Enum.zip(0..n-1)
    |> Enum.map(fn {value, key} -> put(bucket, key, value) end)
  end

  # algorithm2

  def adjust(bucket, n, step \\ 1.0e-4) do
    v = values(bucket)
    k = for x <- 0..n-1, y <- 0..n-1, x < y, do: {x, y}
    d = k |> Enum.map(fn {x, y} -> Tammes.arc_distance(Enum.at(v, x), Enum.at(v, y)) end)
    {i, j} = Enum.at(k, Enum.find_index(d, fn(x) -> x == Enum.min(d) end))
    p1 = Enum.at(v, i)
    p2 = Enum.at(v, j)
    c1 = angle_to_xyz(p1)
    c2 = angle_to_xyz(p2)
    c3 = vector_minus(c1, c2)
    k = dot_product(c1, c3) / dot_product(c1, c1)
    c4 = vector_minus(c3, vector_k(c1, k))
    n = vector_norm(c4)
    f1 =  c4 |> vector_k(1/n*step)
    f2 =  f1 |> vector_k(-1)

    n1 =  xyz_to_angle(vector_add(c1, f1))
    n2 =  xyz_to_angle(vector_add(c2, f2))

    put(bucket, i, n1)
    put(bucket, j, n2) 

  end

  # Agent functions

  def put(bucket, key, value) do
    Agent.update(bucket, &Map.put(&1, key, value))
  end

  def values(bucket) do
    Agent.get(bucket, &Map.values(&1))
  end

  def r(k), do: :rand.uniform * :math.pi * k

  def check(d, a, b, m) do
    a..b 
    |> Enum.map(&(&1/m)) 
    |> List.foldl(0, fn (b, a) ->
                  IO.inspect d |> Enum.map(&(Enum.count(&1, fn x -> x < b and x >= a end))) |> Enum.sum
                  b 
                  end)
    :ok
  end 

  def init(n \\ 15, loop1_times \\ 500_000, loop2_times \\ 2_000_000) do
    {:ok, bucket} = Agent.start_link(fn -> %{} end)
    :rand.seed(:exsplus, :os.timestamp())


    0..n-1 |> Enum.map(&(put(bucket, &1, [r(2), r(1)])))
    # 0..n-1 |> Enum.map(&(put(bucket, &1, Enum.at(v, &1))))

    1..loop1_times |> Enum.map(fn _ -> step(bucket, n) end)
    1..loop2_times |> Enum.map(fn _ -> adjust(bucket, n) end)

    v = values(bucket)
    IO.inspect v
    d = v |> Enum.map(&(Enum.map(v, fn x -> Tammes.arc_distance(x, &1) end)))
    check(d, 935, 940, 1000)

    k = for x <- 0..n-1, y <- 0..n-1, x < y, do: Tammes.arc_distance(Enum.at(v, x), Enum.at(v, y))
    IO.inspect k |> Enum.sort

    :ok
  end  

end