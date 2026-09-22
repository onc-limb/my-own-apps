// このファイルは「画面に出すため」ではなく「何に変換されるかを見るため」にある。
// npm run show:jsx    → 現代の変換（automatic runtime）
// npm run show:jsx:classic → 昔の変換（classic runtime / React.createElement）

export function Greeting({ name, children }: { name: string; children?: React.ReactNode }) {
  return (
    <section className="card" data-name={name}>
      <h3>Hello, {name}</h3>
      {children}
    </section>
  );
}

export const tree = (
  <Greeting name="onc-limb">
    <p>子要素も引数として渡されるだけ</p>
  </Greeting>
);
