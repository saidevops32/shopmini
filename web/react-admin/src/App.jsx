import { useEffect, useState } from 'react'

async function api(path, { method = 'GET', token, body } = {}) {
  const res = await fetch(path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  const data = await res.json().catch(() => null)
  return { ok: res.ok, status: res.status, data }
}

export default function App() {
  const [token, setToken] = useState(null) // kept in memory only
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [products, setProducts] = useState([])
  const [orderId, setOrderId] = useState('')
  const [order, setOrder] = useState(null)

  async function login(e) {
    e.preventDefault()
    setError('')
    const r = await api('/api/auth/login', { method: 'POST', body: { email, password } })
    if (r.ok) setToken(r.data.token)
    else setError(`Login failed (${r.status})`)
  }

  useEffect(() => {
    if (!token) return
    api('/api/catalogue/products', { token }).then((r) => r.ok && setProducts(r.data))
  }, [token])

  async function findOrder(e) {
    e.preventDefault()
    const r = await api(`/api/checkout/orders/${encodeURIComponent(orderId)}`, { token })
    setOrder(r.ok ? r.data : { error: r.status === 404 ? 'Order not found' : `Error ${r.status}` })
  }

  if (!token) {
    return (
      <form onSubmit={login} style={{ maxWidth: 320, margin: '3rem auto', display: 'grid', gap: 8 }}>
        <h2>ShopMini admin</h2>
        <input placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
        <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
        <button type="submit">Log in</button>
        {error && <p style={{ color: 'crimson' }}>{error}</p>}
      </form>
    )
  }

  return (
    <main style={{ maxWidth: 720, margin: '2rem auto' }}>
      <h2>Products</h2>
      <table width="100%">
        <thead><tr><th align="left">ID</th><th align="left">Name</th><th align="right">Price</th><th align="right">Stock</th></tr></thead>
        <tbody>
          {products.map((p) => (
            <tr key={p.id}><td>{p.id}</td><td>{p.name}</td><td align="right">{p.price}</td><td align="right">{p.stock}</td></tr>
          ))}
        </tbody>
      </table>
      <h2>Look up one of your orders</h2>
      <form onSubmit={findOrder}>
        <input placeholder="Order id" value={orderId} onChange={(e) => setOrderId(e.target.value)} />
        <button type="submit">Find</button>
      </form>
      {order && <pre>{JSON.stringify(order, null, 2)}</pre>}
    </main>
  )
}
