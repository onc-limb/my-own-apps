import type { RouteSectionProps } from "@solidjs/router";
import Navbar from "./Navbar";
import "../styles/layout.css";

export default function Layout(props: RouteSectionProps) {
  return (
    <>
      <Navbar />
      <main class="layout-main">{props.children}</main>
    </>
  );
}
