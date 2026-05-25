import { Router, Route } from "@solidjs/router";
import Layout from "./components/Layout";
import Portfolio from "./pages/Portfolio";
import Screening from "./pages/Screening";

export default function App() {
  return (
    <Router root={Layout}>
      <Route path="/" component={Portfolio} />
      <Route path="/screening" component={Screening} />
    </Router>
  );
}
