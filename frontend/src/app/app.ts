import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterModule } from '@angular/router';

// Interfacce per tipizzare i dati del backend
interface OrderItem {
  name: string;
  quantity: number;
  notes?: string;
}

interface Order {
  id: string;
  customerName: string;
  time: string;
  items: OrderItem[];
  total: number;
  status: 'In Attesa' | 'In Preparazione' | 'Pronto';
}

interface MenuItem {
  id: string;
  name: string;
  category: string;
  price: number;
  available: boolean;
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, CommonModule, RouterModule],
  templateUrl: './app.html', // o app.component.html in base a come lo hai chiamato
  styleUrl: './app.css'
})
export class App {
  // --- STATO NAVBAR ---
  isMobileMenuOpen = false;

  toggleMenu() {
    this.isMobileMenuOpen = !this.isMobileMenuOpen;
  }

  closeMenu() {
    this.isMobileMenuOpen = false;
  }

  // --- STATO PANNELLO STAFF ---
  activeTab: 'ordini' | 'menu' = 'ordini';
  activeCategory = 'Tutte';
  categories = ['Tutte', 'Panini', 'Fritti', 'Bevande', 'Menu'];

  // Dati Mock (Da collegare a Flask e SQL in futuro)
  orders: Order[] = [
    {
      id: '#1042',
      customerName: 'Marco R.',
      time: '19:30',
      items: [
        { name: 'SmashBoss Double', quantity: 2, notes: 'Senza cipolla' },
        { name: 'Patatine Cheddar & Bacon', quantity: 1 }
      ],
      total: 24.50,
      status: 'In Attesa'
    },
    {
      id: '#1043',
      customerName: 'Giulia B.',
      time: '19:35',
      items: [
        { name: 'Chicken Crunch', quantity: 1 },
        { name: 'Coca Cola Zero', quantity: 1 }
      ],
      total: 12.00,
      status: 'In Preparazione'
    }
  ];

  menuItems: MenuItem[] = [
    { id: 'p1', name: 'SmashBoss Double', category: 'Panini', price: 10.50, available: true },
    { id: 'p2', name: 'Chicken Crunch', category: 'Panini', price: 9.00, available: true },
    { id: 'f1', name: 'Patatine Cheddar & Bacon', category: 'Fritti', price: 5.50, available: true },
    { id: 'b1', name: 'Coca Cola', category: 'Bevande', price: 3.00, available: true },
  ];

  // --- LOGICA ORDINI ---
  changeOrderStatus(orderId: string, newStatus: Order['status']) {
    const order = this.orders.find(o => o.id === orderId);
    if (order) {
      order.status = newStatus;
      // TODO: Chiamata API Flask per aggiornare lo stato
    }
  }

  // --- LOGICA MENU ---
  deleteMenuItem(id: string) {
    if(confirm('Sei sicuro di voler eliminare questo prodotto?')) {
      this.menuItems = this.menuItems.filter(item => item.id !== id);
      // TODO: Chiamata API Flask per eliminare
    }
  }

  toggleAvailability(item: MenuItem) {
    item.available = !item.available;
    // TODO: Chiamata API Flask per aggiornare disponibilità
  }

  openAddProductModal() {
    alert('Qui apriremo il modale per inserire un nuovo prodotto!');
  }

  editProduct(item: MenuItem) {
    alert(`Qui apriremo il modale per modificare: ${item.name}`);
  }
}