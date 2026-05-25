import { A } from "@solidjs/router";
import "../styles/navbar.css";

export default function Navbar() {
  return (
    <nav class="navbar">
      <strong class="navbar-brand">投資資産管理</strong>
      <A href="/" class="navbar-link" activeClass="active-link" end>
        ポートフォリオ
      </A>
      <A href="/screening" class="navbar-link" activeClass="active-link">
        スクリーニング
      </A>
    </nav>
  );
}
