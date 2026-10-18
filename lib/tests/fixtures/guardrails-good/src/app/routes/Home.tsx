import { useState } from "react";

export function Home() {
  const [n] = useState(0);
  return <p>{n}</p>;
}
